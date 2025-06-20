    use starknet::{ContractAddress, ClassHash, };
    use starknet::testing::{set_caller_address, set_contract_address};
    //use super::{TokenSale, ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
    use crate::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
    use crate::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc20::ERC20Component;
    //
    use snforge_std::{declare, ContractClassTrait, test_address, Cheatcode, start_prank, stop_prank, Contract};

    const OWNER: ContractAddress = contract_address_const!("0x123");
    const BUYER: ContractAddress = contract_address_const!("0x456");
    const PAYMENT_TOKEN: ContractAddress = contract_address_const!("0x789");
    const SALE_TOKEN: ContractAddress = contract_address_const!("0xabc");

    fn setup() -> (ITokenSaleDispatcher, IERC20Dispatcher, IERC20Dispatcher) {
        // Deploy tokens
        let payment_token = declare("PaymentToken").deploy(@array![]).unwrap();
        let sale_token = declare("SaleToken").deploy(@array![]).unwrap();

        // Deploy TokenSale
        let token_sale_class = declare("TokenSale");
        let token_sale = token_sale_class.deploy(@array![OWNER, payment_token.contract_address]).unwrap();

        // Initialize tokens
        payment_token.initializer(OWNER, 'PaymentToken', 'PT', 18);
        sale_token.initializer(OWNER, 'SaleToken', 'ST', 18);

        (token_sale, payment_token, sale_token)
    }

    // Helper to mint tokens
    fn mint_tokens(token: IERC20Dispatcher, to: ContractAddress, amount: u256) {
        start_prank(OWNER);
        token.mint(to, amount);
        stop_prank();
    }

    // Helper to approve transfers
    fn approve(token: IERC20Dispatcher, spender: ContractAddress, amount: u256) {
        token.approve(spender, amount);
    }

#[test]
fn test_constructor_initialization() {
    let (token_sale, payment_token, _) = setup();
    
    assert_eq!(
        token_sale.accepted_payment_token(), 
        payment_token.contract_address,
        "Payment token mismatch"
    );
    
    assert_eq!(
        token_sale.owner(),
        OWNER,
        "Owner not set correctly"
    );
}

#[test]
fn test_deposit_tokens() {
    let (token_sale, _, sale_token) = setup();
    let amount = 1000_u256;
    let price = 10_u256;

    // Mint tokens to owner and approve
    mint_tokens(sale_token, OWNER, amount);
    start_prank(OWNER);
    sale_token.approve(token_sale.contract_address, amount);
    
    // Deposit tokens
    token_sale.deposit(sale_token.contract_address, amount, price);
    stop_prank();

    // Verify state updates
    assert_eq!(
        token_sale.tokens_available_for_sale(sale_token.contract_address),
        amount,
        "Tokens not deposited"
    );
    
    assert_eq!(
        token_sale.token_price(sale_token.contract_address),
        price,
        "Price not set"
    );
}

#[test]
#[should_panic(expected: ('Ownable: caller is not the owner',))]
fn test_deposit_non_owner_fails() {
    let (token_sale, _, sale_token) = setup();
    start_prank(BUYER); // Non-owner
    token_sale.deposit(sale_token.contract_address, 1000_u256, 10_u256);
}

#[test]
fn test_buy_tokens() {
    let (token_sale, payment_token, sale_token) = setup();
    let deposit_amount = 1000_u256;
    let buy_amount = 100_u256;
    let price = 10_u256;
    let total_price = price * buy_amount;

    // Setup tokens
    mint_tokens(sale_token, OWNER, deposit_amount);
    mint_tokens(payment_token, BUYER, total_price);
    
    // Owner deposits sale tokens
    start_prank(OWNER);
    sale_token.approve(token_sale.contract_address, deposit_amount);
    token_sale.deposit(sale_token.contract_address, deposit_amount, price);
    stop_prank();
    
    // Buyer approves payment
    start_prank(BUYER);
    payment_token.approve(token_sale.contract_address, total_price);
    
    // Execute purchase
    token_sale.buy_token(sale_token.contract_address, buy_amount);
    stop_prank();

    // Verify state changes
    assert_eq!(
        token_sale.tokens_available_for_sale(sale_token.contract_address),
        deposit_amount - buy_amount,
        "Available tokens not updated"
    );
    
    assert_eq!(
        sale_token.balance_of(BUYER),
        buy_amount,
        "Buyer didn't receive tokens"
    );
    
    assert_eq!(
        payment_token.balance_of(token_sale.contract_address),
        total_price,
        "Contract didn't receive payment"
    );
}

#[test]
#[should_panic(expected: ('Not enough tokens available',))]
fn test_buy_insufficient_available_tokens() {
    // Setup with 100 tokens available
    let (token_sale, payment_token, sale_token) = setup();
    mint_tokens(sale_token, OWNER, 100_u256);
    mint_tokens(payment_token, BUYER, 1000_u256);
    
    start_prank(OWNER);
    sale_token.approve(token_sale.contract_address, 100_u256);
    token_sale.deposit(sale_token.contract_address, 100_u256, 10_u256);
    stop_prank();
    
    // Attempt to buy 200 tokens
    start_prank(BUYER);
    payment_token.approve(token_sale.contract_address, 2000_u256);
    token_sale.buy_token(sale_token.contract_address, 200_u256);
}

#[test]
#[should_panic(expected: ('Buyer does not have enough balance',))]
fn test_buy_insufficient_payment_balance() {
    // Setup
    let (token_sale, payment_token, sale_token) = setup();
    mint_tokens(sale_token, OWNER, 1000_u256);
    mint_tokens(payment_token, BUYER, 50_u256); // Less than needed
    
    start_prank(OWNER);
    sale_token.approve(token_sale.contract_address, 1000_u256);
    token_sale.deposit(sale_token.contract_address, 1000_u256, 10_u256);
    stop_prank();
    
    // Attempt purchase
    start_prank(BUYER);
    payment_token.approve(token_sale.contract_address, 1000_u256);
    token_sale.buy_token(sale_token.contract_address, 100_u256); // Requires 1000 tokens
}

#[test]
fn test_upgrade_implementation() {
    let (token_sale, _, _) = setup();
    let new_class_hash = class_hash_const!("0xNEW");
    
    start_prank(OWNER);
    token_sale.upgrade(new_class_hash);
    stop_prank();
    
    // Verify upgrade (pseudocode - actual verification depends on upgrade logic)
    // assert_eq!(get_implementation(token_sale.contract_address), new_class_hash);
}

#[test]
#[should_panic(expected: ('Ownable: caller is not the owner',))]
fn test_upgrade_non_owner_fails() {
    let (token_sale, _, _) = setup();
    start_prank(BUYER);
    token_sale.upgrade(class_hash_const!("0xNEW"));
}

#[test]
fn test_token_availability() {
    let (token_sale, _, sale_token) = setup();
    let amount = 500_u256;
    
    // Deposit tokens
    mint_tokens(sale_token, OWNER, amount);
    start_prank(OWNER);
    sale_token.approve(token_sale.contract_address, amount);
    token_sale.deposit(sale_token.contract_address, amount, 10_u256);
    stop_prank();
    
    // Check availability
    let available = token_sale.check_available_token(sale_token.contract_address);
    assert_eq!(available, amount, "Incorrect available balance");
}

