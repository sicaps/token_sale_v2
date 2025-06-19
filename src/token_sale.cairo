#[starknet::contract]
mod TokenSale {
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::interfaces::itoken_sale::ITokenSale;
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    use openzeppelin::access::ownable::OwnableComponent;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    #[storage]
    struct Storage {
        accepted_payment_token: ContractAddress,
        token_price: Map<ContractAddress, u256>,
        tokens_available_for_sale: Map<ContractAddress, u256>,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, accepted_payment_token: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.accepted_payment_token.write(accepted_payment_token);
    }

    #[abi(embed_v0)]
    impl TokenSaleImpl of ITokenSale<ContractState> {
        fn check_available_token(self: @ContractState, token_address: ContractAddress) -> u256 {
            let token = IERC20Dispatcher { contract_address: token_address };
            let balance = token.balance_of(get_contract_address());
            balance
        }

        fn deposit(
            ref self: ContractState,
            token_address: ContractAddress,
            amount: u256,
            token_price: u256,
        ) {
            self.ownable.assert_only_owner();

            let caller_address = get_caller_address();
            let this_contract_address = get_contract_address();

            let token = IERC20Dispatcher { contract_address: token_address };
            assert!(
                token.balance_of(caller_address) >= amount, "Caller does not have enough balance",
            );

            let transfer = token.transfer_from(caller_address, this_contract_address, amount);
            assert(transfer, 'Transfer failed');

            self.tokens_available_for_sale.entry(token_address).write(amount);
            self.token_price.entry(token_address).write(token_price);
        }

        fn buy_token(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let available_amount = self.tokens_available_for_sale.entry(token_address).read();
            assert(available_amount >= amount, 'Not enough tokens available');

            let buyer_address = get_caller_address();
            let this_contract_address = get_contract_address();

            let payment_token = IERC20Dispatcher {
                contract_address: self.accepted_payment_token.read(),
            };
            let token_to_buy = IERC20Dispatcher { contract_address: token_address };

            let unit_price = self.token_price.entry(token_address).read();
            let total_price = unit_price * amount;
            let buyer_balance = payment_token.balance_of(buyer_address);

            assert!(buyer_balance >= total_price, "Buyer does not have enough balance");

            let payment_success = payment_token
                .transfer_from(buyer_address, this_contract_address, total_price);
            assert(payment_success, 'Payment transfer failed');

            let token_success = token_to_buy.transfer(buyer_address, amount);
            assert(token_success, 'Token transfer failed');

            // Update available tokens
            let remaining_tokens = available_amount - amount;
            self.tokens_available_for_sale.entry(token_address).write(remaining_tokens);
        }

        fn upgrade(ref self: ContractState, new_implementation: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_implementation);
        }
    }
}