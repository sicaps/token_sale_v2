#[cfg(test)] mod tests {
use super::TokenSale;
use starknet::{ContractAddress, ClassHash, contract_address_const};
use starknet::testing::{set_caller_address};
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, spy_events, SpyOn};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use crate::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
use crate::mocks::mock_erc20::IMockERC20Dispatcher;


// Helper function to deploy mock ERC20 contract
fn deploy_mock_erc20(name: felt252, symbol: felt252, decimals: u8) -> ContractAddress {
    let contract = declare("MockERC20").unwrap();
    let mut calldata = array![name, symbol, decimals.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Helper function to deploy TokenSale contract
fn deploy_token_sale(owner: ContractAddress, payment_token: ContractAddress) -> ContractAddress {
    let contract = declare("TokenSale").unwrap();
    let mut calldata = array![owner.into(), payment_token.into()];
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_constructor() {
    let owner = contract_address_const::<1>();
    let payment_token = contract_address_const::<2>();
    let token_sale_address = deploy_token_sale(owner, payment_token);

    // Check owner
    let ownable = IOwnableDispatcher { contract_address: token_sale_address };
    assert(ownable.owner() == owner, 'Owner not set correctly');
}

#[test]
fn test_check_available_token() {
    let owner = contract_address_const::<1>();
    let payment_token = contract_address_const::<2>();
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };

    // Mint tokens to contract
    set_caller_address(owner);
    mock_token.mint(token_sale_address, 100 * 10_u256.pow(18));

    // Check balance
    let balance = token_sale.check_available_token(token_address);
    assert(balance == 100 * 10_u256.pow(18), 'Incorrect token balance');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_deposit_non_owner() {
    let owner = contract_address_const::<1>();
    let non_owner = contract_address_const::<2>();
    let payment_token = deploy_mock_erc20('PaymentToken', 'PT', 18);
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };

    // Setup non-owner with tokens
    mock_token.mint(non_owner, 100 * 10_u256.pow(18));
    start_prank(token_sale_address, non_owner);
    mock_token.approve(token_sale_address, 100 * 10_u256.pow(18));

    // Attempt deposit
    token_sale.deposit(token_address, 50 * 10_u256.pow(18), 1 * 10_u256.pow(18));
}

#[test]
fn test_deposit() {
    let owner = contract_address_const::<1>();
    let payment_token = deploy_mock_erc20('PaymentToken', 'PT', 18);
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_token = IERC20Dispatcher { contract_address: token_address };
    let mock_token_dispatcher = IMockERC20Dispatcher { contract_address: token_address };

    // Setup owner with tokens
    start_prank(token_address, owner);
    mock_token_dispatcher.mint(owner, 100 * 10_u256.pow(18));
    mock_token.approve(token_sale_address, 100 * 10_u256.pow(18));
    stop_prank();

    // Deposit tokens
    start_prank(token_sale_address, owner);
    token_sale.deposit(token_address, 50 * 10_u256.pow(18), 1 * 10_u256.pow(18));
    stop_prank();

    // Verify token transfer
    assert(mock_token.balance_of(token_sale_address) == 50 * 10_u256.pow(18), 'Tokens not transferred');
}

#[test]
#[should_panic(expected: ('Not enough tokens available',))]
fn test_buy_token_insufficient_tokens() {
    let owner = contract_address_const::<1>();
    let buyer = contract_address_const::<2>();
    let payment_token = deploy_mock_erc20('PaymentToken', 'PT', 18);
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_payment = IMockERC20Dispatcher { contract_address: payment_token };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };

    // Deposit tokens
    start_prank(token_address, owner);
    mock_token.mint(owner, 100 * 10_u256.pow(18));
    mock_token.approve(token_sale_address, 100 * 10_u256.pow(18));
    stop_prank();
    start_prank(token_sale_address, owner);
    token_sale.deposit(token_address, 100 * 10_u256.pow(18), 1 * 10_u256.pow(18));
    stop_prank();

    // Setup buyer
    start_prank(payment_token, buyer);
    mock_payment.mint(buyer, 150 * 10_u256.pow(18));
    mock_payment.approve(token_sale_address, 150 * 10_u256.pow(18));
    stop_prank();

    // Attempt to buy too many tokens
    start_prank(token_sale_address, buyer);
    token_sale.buy_token(token_address, 150 * 10_u256.pow(18));
}

#[test]
fn test_buy_token() {
    let owner = contract_address_const::<1>();
    let buyer = contract_address_const::<2>();
    let payment_token = deploy_mock_erc20('PaymentToken', 'PT', 18);
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_payment = IERC20Dispatcher { contract_address: payment_token };
    let mock_token = IERC20Dispatcher { contract_address: token_address };
    let mock_payment_dispatcher = IMockERC20Dispatcher { contract_address: payment_token };
    let mock_token_dispatcher = IMockERC20Dispatcher { contract_address: token_address };

    // Deposit tokens
    start_prank(token_address, owner);
    mock_token_dispatcher.mint(owner, 100 * 10_u256.pow(18));
    mock_token.approve(token_sale_address, 100 * 10_u256.pow(18));
    stop_prank();
    start_prank(token_sale_address, owner);
    token_sale.deposit(token_address, 100 * 10_u256.pow(18), 1 * 10_u256.pow(18));
    stop_prank();

    // Setup buyer
    start_prank(payment_token, buyer);
    mock_payment_dispatcher.mint(buyer, 50 * 10_u256.pow(18));
    mock_payment.approve(token_sale_address, 50 * 10_u256.pow(18));
    stop_prank();

    // Buy tokens
    start_prank(token_sale_address, buyer);
    token_sale.buy_token(token_address, 50 * 10_u256.pow(18));
    stop_prank();

    // Verify balances
    assert(mock_token.balance_of(buyer) == 50 * 10_u256.pow(18), 'Buyer did not receive tokens');
    assert(mock_payment.balance_of(token_sale_address) == 50 * 10_u256.pow(18), 'Contract did not receive payment');
    assert(token_sale.check_available_token(token_address) == 50 * 10_u256.pow(18), 'Available tokens not updated');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_upgrade_non_owner() {
    let owner = contract_address_const::<1>();
    let non_owner = contract_address_const::<2>();
    let payment_token = contract_address_const::<3>();
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let new_class_hash = starknet::class_hash_const::<0x123>();

    // Attempt upgrade as non-owner
    start_prank(token_sale_address, non_owner);
    token_sale.upgrade(new_class_hash);
}

#[test]
fn test_upgrade() {
    let owner = contract_address_const::<1>();
    let payment_token = contract_address_const::<2>();
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let new_class_hash = starknet::class_hash_const::<0x123>();

    // Upgrade as owner
    start_prank(token_sale_address, owner);
    token_sale.upgrade(new_class_hash);
    stop_prank();
}

#[test]
fn test_deposit_and_buy_integration() {
    let owner = contract_address_const::<1>();
    let buyer = contract_address_const::<2>();
    let payment_token = deploy_mock_erc20('PaymentToken', 'PT', 18');
    let token_address = deploy_mock_erc20('SoldToken', 'ST', 18);
    let token_sale_address = deploy_token_sale(owner, payment_token);
    let token_sale = ITokenSaleDispatcher { contract_address: token_sale_address };
    let mock_payment = IERC20Dispatcher { contract_address: payment_token };
    let mock_token = IERC20Dispatcher { contract_address: token_address };
    let mock_token_dispatcher = IMockERC20Dispatcher { contract_address: token_address };
    let mock_payment_dispatcher = IMockERC20Dispatcher { contract_address: payment_token };

    // Deposit tokens
    start_prank(token_address, owner);
    mock_token_dispatcher.mint(owner, 100 * 10_u256.pow(18));
    mock_token.approve(token_sale_address, 100 * 10_u256.pow(18));
    stop_prank();
    start_prank(token_sale_address, owner);
    token_sale.deposit(token_address, 100 * 10_u256.pow(18), 1 * 10_u256.pow(18));
    stop_prank();

    // Setup buyer
    start_prank(payment_token, buyer);
    mock_payment_dispatcher.mint(buyer, 50 * 10_u256.pow(18));
    mock_payment.approve(token_sale_address, 50 * 10_u256.pow(18));
    stop_prank();

    // Buy tokens
    start_prank(token_sale_address, buyer);
    token_sale.buy_token(token_address, 50 * 10_u256.pow(18));
    stop_prank();

    // Verify balances
    assert(mock_token.balance_of(buyer) == 50 * 10_u256.pow(18), 'Buyer did not receive tokens');
    assert(mock_payment.balance_of(token_sale_address) == 50 * 10_u256.pow(18), 'Contract did not receive payment');
    assert(token_sale.check_available_token(token_address) == 50 * 10_u256.pow(18), 'Available tokens not updated');
}
};
