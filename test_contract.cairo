// Import the interface and dispatcher to be able to interact with the contract.

// Import the required traits and functions from Snforge
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
// And additionally the testing utilities
use snforge_std::{load, start_cheat_caller_address_global, stop_cheat_caller_address_global};
use token_sale_v2::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};

// Declare and deploy the contract and return its dispatcher.
fn deploy(max_capacity: u32) -> ITokenSaleDispatcher {
    let contract = declare("TokenSale").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![max_capacity.into()]).unwrap();

    // Return the dispatcher.
    // It allows to interact with the contract based on its interface.
    ITokenSaleDispatcher { contract_address }
}

#[test]
fn test_deploy() {
    let max_capacity: u32 = 100;
    let contract = deploy(max_capacity);

    assert_eq!(contract.get_max_capacity(), max_capacity);
    assert_eq!(contract.get_inventory_count(), 0);
}

#[test]
fn test_buy() {
    let max_capacity: u32 = 100;
    let contract = deploy(max_capacity);

    assert_eq!(contract.get_max_capacity(), max_capacity);
    assert_eq!(contract.get_inventory_count(), 0);

    let buyer_address = load("buyer_address");
    start_cheat_caller_address_global(buyer_address);

    let amount_to_buy = 10;
    contract.buy(amount_to_buy).unwrap();

    assert_eq!(contract.get_inventory_count(), amount_to_buy);

    stop_cheat_caller_address_global();
}

#[test]
fn test_sell() {
    let max_capacity: u32 = 100;
    let contract = deploy(max_capacity);

    assert_eq!(contract.get_max_capacity(), max_capacity);
    assert_eq!(contract.get_inventory_count(), 0);

    let buyer_address = load("buyer_address");
    start_cheat_caller_address_global(buyer_address);

    let amount_to_buy = 10;
    contract.buy(amount_to_buy).unwrap();

    assert_eq!(contract.get_inventory_count(), amount_to_buy);

    stop_cheat_caller_address_global();

    let seller_address = load("seller_address");
    start_cheat_caller_address_global(seller_address);

    let amount_to_sell = 5;
    contract.sell(amount_to_sell).unwrap();

    assert_eq!(contract.get_inventory_count(), amount_to_buy - amount_to_sell);

    stop_cheat_caller_address_global();
}

#[test]
fn test_sell_insufficient_inventory() {
    let max_capacity: u32 = 100;
    let contract = deploy(max_capacity);

    assert_eq!(contract.get_max_capacity(), max_capacity);
    assert_eq!(contract.get_inventory_count(), 0);

    let buyer_address = load("buyer_address");
    start_cheat_caller_address_global(buyer_address);

    let amount_to_buy = 10;
    contract.buy(amount_to_buy).unwrap();

    assert_eq!(contract.get_inventory_count(), amount_to_buy);

    stop_cheat_caller_address_global();

    let seller_address = load("seller_address");
    start_cheat_caller_address_global(seller_address);

    let amount_to_sell = 15;
    let result = contract.sell(amount_to_sell);

    assert_eq!(result, Err(ErrorCode::INSUFFICIENT_INVENTORY));

    stop_cheat_caller_address_global();
}
