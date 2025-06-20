#[cfg(test)]
mod tests {
    use super::TokenSale;
    use starknet::{ContractAddress, ClassHash, contract_address_const};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::{set_contract_address, set_caller_address};
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use crate::mocks::mock_erc20::IMockERC20Dispatcher;

    // Helper function to deploy mock ERC20 contract
    fn deploy_mock_erc20(name: felt252, symbol: felt252, decimals: u8) -> ContractAddress {
        let class_hash = declare("MockERC20").unwrap();
        let mut calldata = array![name, symbol, decimals.into()];
        let (contract_address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
        contract_address
    }

    // Helper function to deploy TokenSale contract
    fn deploy_token_sale(owner: ContractAddress, payment_token: ContractAddress) -> ContractAddress {
        let class_hash = declare("TokenSale").unwrap();
        let mut calldata = array![owner.into(), payment_token.into()];
        let (contract_address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
        contract_address
    }

    #[test]
    fn test_constructor() {
        let owner = contract_address_const::<1>();
        let payment_token = contract_address_const::<2>();
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };

        // Check owner using OwnableComponent
        let contract_owner = token_sale.owner();
        assert(contract_owner == owner, 'Owner not set correctly');

        // Note: Since accepted_payment_token has no getter, we assume it can be tested indirectly
        // or a getter is added in practice. For this test, we skip direct storage read.
    }

    #[test]
    fn test_check_available_token() {
        let token_address = deploy_mock_erc20("SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(contract_address_const::<1>(), contract_address_const::<2>());
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_st = IMockERC20Dispatcher { contract_address: token_address };

        // Mint tokens to the contract
        set_caller_address(contract_address_const::<0>());
        mock_st.mint(token_sale_address, 100 * 10^18);

        // Check available token
        let available = token_sale.check_available_token(token_address);
        assert(available == 100 * 10^18, 'Incorrect available token');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_deposit_non_owner() {
        let owner = contract_address_const::<1>();
        let payment_token = deploy_mock_erc20("PaymentToken", "PT", 18);
        let token_address = deploy_mock_erc20("SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_st = IMockERC20Dispatcher { contract_address: token_address };

        // Set up non-owner
        let non_owner = contract_address_const::<3>();
        mock_st.mint(non_owner, 100 * 10^18);
        mock_st.approve(token_sale_address, 100 * 10^18);

        // Attempt deposit as non-owner
        start_prank(non_owner, token_sale_address);
        token_sale.deposit(token_address, 50 * 10^18, 1 * 10^18);
    }

    #[test]
    fn test_deposit() {
        let owner = contract_address_const::<1>();
        let payment_token = deploy_mock_erc20("PaymentToken", "PT", 18);
        let token_address = deploy_mock_erc20("SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_st = IERC20Dispatcher { contract_address: token_address };

        // Set up owner with tokens
        let mock_st_mock = IMockERC20Dispatcher { contract_address: token_address };
        mock_st_mock.mint(owner, 100 * 10^18);
        mock_st.approve(token_sale_address, 100 * 10^18);

        // Deposit as owner
        start_prank(owner, token_sale_address);
        token_sale.deposit(token_address, 50 * 10^18, 1 * 10^18);
        stop_prank();

        // Check that tokens are transferred to the contract
        assert(mock_st.balance_of(token_sale_address) == 50 * 10^18, 'Tokens not transferred');
    }

    #[test]
    #[should_panic(expected: ('Not enough tokens available',))]
    fn test_buy_token_insufficient_tokens() {
        let owner = contract_address_const::<1>();
        let payment_token = deploy_mock_erc20("PaymentToken", "PT", 18);
        let token_address = deploy_mock_erc20="SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_pt = IMockERC20Dispatcher { contract_address: payment_token };
        let mock_st = IMockERC20Dispatcher { contract_address: token_address };

        // Deposit tokens
        mock_st.mint(owner, 100 * 10^18);
        mock_st.approve(token_sale_address, 100 * 10^18);
        start_prank(owner, token_sale_address);
        token_sale.deposit(token_address, 100 * 10^18, 1 * 10^18);
        stop_prank();

        // Set up buyer
        let buyer = contract_address_const::<2>();
        mock_pt.mint(buyer, 150 * 10^18);
        mock_pt.approve(token_sale_address, 150 * 10^18);

        // Attempt to buy more than available
        start_prank(buyer, token_sale_address);
        token_sale.buy_token(token_address, 150 * 10^18);
    }

    #[test]
    fn test_buy_token() {
        let owner = contract_address_const::<1>();
        let payment_token = deploy_mock_erc20("PaymentToken", "PT", 18);
        let token_address = deploy_mock_erc20("SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_pt = IERC20Dispatcher { contract_address: payment_token };
        let mock_st = IERC20Dispatcher { contract_address: token_address };

        // Deposit tokens
        let mock_st_mock = IMockERC20Dispatcher { contract_address: token_address };
        mock_st_mock.mint(owner, 100 * 10^18);
        mock_st.approve(token_sale_address, 100 * 10^18);
        start_prank(owner, token_sale_address);
        token_sale.deposit(token_address, 100 * 10^18, 1 * 10^18);
        stop_prank();

        // Set up buyer
        let buyer = contract_address_const::<2>();
        let mock_pt_mock = IMockERC20Dispatcher { contract_address: payment_token };
        mock_pt_mock.mint(buyer, 50 * 10^18);
        mock_pt.approve(token_sale_address, 50 * 10^18);

        // Buy tokens
        start_prank(buyer, token_sale_address);
        token_sale.buy_token(token_address, 50 * 10^18);
        stop_prank();

        // Check balances
        assert(mock_st.balance_of(buyer) == 50 * 10^18, 'Buyer did not receive tokens');
        assert(mock_pt.balance_of(token_sale_address) == 50 * 10^18, 'Contract did not receive payment');
        assert(token_sale.check_available_token(token_address) == 50 * 10^18, 'Available tokens not updated');
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_upgrade_non_owner() {
        let owner = contract_address_const::<1>();
        let payment_token = contract_address_const::<2>();
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let new_implementation = starknet::class_hash_const::<3>();

        // Attempt upgrade as non-owner
        let non_owner = contract_address_const::<3>();
        start_prank(non_owner, token_sale_address);
        token_sale.upgrade(new_implementation);
    }

    #[test]
    fn test_upgrade() {
        let owner = contract_address_const::<1>();
        let payment_token = contract_address_const::<2>();
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let new_implementation = starknet::class_hash_const::<3>();

        // Upgrade as owner
        start_prank(owner, token_sale_address);
        token_sale.upgrade(new_implementation);
        stop_prank();
    }

    #[test]
    fn test_deposit_and_buy_integration() {
        let owner = contract_address_const::<1>();
        let payment_token = deploy_mock_erc20("PaymentToken", "PT", 18);
        let token_address = deploy_mock_erc20("SoldToken", "ST", 18);
        let token_sale_address = deploy_token_sale(owner, payment_token);
        let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
        let mock_pt = IERC20Dispatcher { contract_address: payment_token };
        let mock_st = IERC20Dispatcher { contract_address: token_address };

        // Deposit tokens
        let mock_st_mock = IMockERC20Dispatcher { contract_address: token_address };
        mock_st_mock.mint(owner, 100 * 10^18);
        mock_st.approve(token_sale_address, 100 * 10^18);
        start_prank(owner, token_sale_address);
        token_sale.deposit(token_address, 100 * 10^18, 1 * 10^18);
        stop_prank();

        // Buy tokens
        let buyer = contract_address_const::<2>();
        let mock_pt_mock = IMockERC20Dispatcher { contract_address: payment_token };
        mock_pt_mock.mint(buyer, 50 * 10^18);
        mock_pt.approve(token_sale_address, 50 * 10^18);
        start_prank(buyer, token_sale_address);
        token_sale.buy_token(token_address, 50 * 10^18);
        stop_prank();

        // Check balances
        assert(mock_st.balance_of(buyer) == 50 * 10^18, 'Buyer did not receive tokens');
        assert(mock_pt.balance_of(token_sale_address) == 50 * 10^18, 'Contract did not receive payment');
        assert(token_sale.check_available_token(token_address) == 50 * 10^18, 'Available tokens not updated');
    }
}
