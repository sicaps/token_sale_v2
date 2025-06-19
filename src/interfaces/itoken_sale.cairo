use starknet::{ClassHash, ContractAddress};
#[starknet::interface]
pub trait ITokenSale<TState> {
    fn check_available_token(self: @TState, token_address: ContractAddress) -> u256;
    fn deposit(ref self: TState, token_address: ContractAddress, amount: u256, token_price: u256);
    fn buy_token(ref self: TState, token_address: ContractAddress, amount: u256);
    fn upgrade(ref self: TState, new_implementation: ClassHash);
}
