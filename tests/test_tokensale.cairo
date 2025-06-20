//use token_sale_v2::token_sale::TokenSale;
use token_sale_v2::interfaces::itoken_sale::{ITokenSaleDispatcher, ITokenSaleDispatcherTrait};
use token_sale_v2::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

// Required for declaring and deploying a contract
use snforge_std::{declare, DeclareResultTrait, ContractClassTrait};

// use snforge_std::{
//     start_cheat_caller_address,
//     stop_cheat_caller_address,
// };
use starknet::{ContractAddress, };


pub mod Accounts {
    use starknet::ContractAddress;
    use core::traits::TryInto;

    pub fn OWNER() -> ContractAddress {
        'OWNER'.try_into().unwrap()
    }

    pub fn PAYMENT_TOKEN() -> ContractAddress {
        'PAYMENT_TOKEN'.try_into().unwrap()
    }
}

fn deploy_token_sale_with_args(name: ByteArray) -> ContractAddress {
    let contract_class = declare(name).unwrap().contract_class();
    let constructor_args = array![Accounts::OWNER().into(), Accounts::PAYMENT_TOKEN().into()];
    let (contract_address, _) = contract_class.deploy(@constructor_args).unwrap();
    contract_address
}

#[test]
fn test_deploy_token_sale_with_args() {
    let token_sale_address = deploy_token_sale_with_args("TokenSale");
    assert_eq!(token_sale_address, 'TOKEN_SALE'.try_into().unwrap());
}

#[test]
fn tests_to_be_implemented() {
    // TODO: Implement tests over the next few days
}
