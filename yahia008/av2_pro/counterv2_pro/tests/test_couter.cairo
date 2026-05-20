use starknet::SyscallResultTrait;
use snforge_std::DeclareResultTrait;
use counterv2_pro::CounterV2;
use starknet::testing::{
    set_contract_address, set_caller_address
};
use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address, };
use counterv2_pro::{ICounterDispatcher, ICounterDispatcherTrait};
use starknet::syscalls::deploy_syscall; 
use starknet::ContractAddress;
use starknet::contract_address_const;

const U128_MAX: u128 = 340282366920938463463374607431768211455;

  fn owner() -> ContractAddress {

      contract_address_const::<0x1>()
    }

    fn attacker() -> ContractAddress {
        contract_address_const::<0x2>()
    }

    fn new_owner() -> ContractAddress {
        contract_address_const::<0x3>()
    }

fn deploy_contract(initial_owner: ContractAddress) -> ICounterDispatcher {
    let contract = declare("CounterV2").unwrap_syscall().contract_class();

    let mut calldata = array![initial_owner.into()];

    let (contract_address, _) = contract.deploy(@calldata).unwrap_syscall();

    ICounterDispatcher { contract_address }
}

#[cfg(test)]
mod tests {
    use super::*;

    use super::new_owner;
use counterv2_pro::ICounterDispatcherTrait;
use snforge_std::start_cheat_caller_address;
use super::deploy_contract;
use super::attacker;
use super::owner;
use starknet::SyscallResultTrait;
    #[test]
    fn test_constructor(){
    let initial_owner = owner();
    let counter = deploy_contract(initial_owner);
    assert!(counter.get_count() == 0, "initial count should be zero") 
    assert!(counter.get_owner() == initial_owner, "owner is initial owner"); 
    }

        #[test]
    fn test_increase_count() {
        let owner = owner();
        let counter = deploy_contract(owner);
        
        start_cheat_caller_address(counter.contract_address, owner);
        
        counter.increase_count(5);
        assert_eq!(counter.get_count(), 5);
        
        counter.increase_count(3);
        assert_eq!(counter.get_count(), 8);
    }

    #[test]
    #[should_panic(expected: "Only owner can change state")]
    fn test_increase_count_not_owner() {
        let owner = owner();
        let counter = deploy_contract(owner);
        
        let attacker = attacker();
        start_cheat_caller_address(counter.contract_address, attacker);
        
        counter.increase_count(5); // Should panic
    }
    #[test]
    fn test_increase_count_by_zero() {
       let owner =  owner();
        let  counter = deploy_contract(owner);

        start_cheat_caller_address(counter.contract_address, owner);
        counter.increase_count(0);
        assert_eq!(counter.get_count(), 0);

        counter.increase_count(5);
        counter.increase_count(0);

        assert_eq!(counter.get_count(), 5,);
       
    }

    #[test]
    #[should_panic]

    fn test_increase_count_overflow() {
    let owner = owner();
    let counter = deploy_contract(owner);
    
    start_cheat_caller_address(counter.contract_address, owner);
    
    counter.increase_count(U128_MAX);
    assert_eq!(counter.get_count(), U128_MAX);
    
    counter.increase_count(1);
}    

    #[test]
    fn test_decrease_count_by_owner() {
       let owner = owner();
        let counter = deploy_contract(owner);

     start_cheat_caller_address(counter.contract_address, owner);
        counter.increase_count(20);
        counter.decrease_count(7);
        assert!(counter.get_count() == 13, "Count should be 13 after decrease");
    }


    #[test]
    fn test_decrease_count_to_zero() {
        let owner = owner();
        let counter = deploy_contract(owner);
        start_cheat_caller_address(counter.contract_address, owner);
        counter.increase_count(5);
        counter.decrease_count(5);
        assert!(counter.get_count() == 0, "Count should reach exactly 0");
    }

    #[test]
    #[should_panic]
    fn test_decrease_count_below_zero_panics() {
        let owner = owner();
        let counter = deploy_contract(owner);

     start_cheat_caller_address(counter.contract_address, owner);

        counter.decrease_count(1); // count is 0, underflow expected
    }

    
    #[test]
    #[should_panic(expected: "Only owner can change state")]
    fn test_decrease_count_by_non_owner_panics() {
         let owner = owner();
        let counter = deploy_contract(owner);
        counter.increase_count(10);

         start_cheat_caller_address(counter.contract_address, attacker());
        counter.decrease_count(5);
    }

    #[test]
    fn test_decrease_count_by_zero() {
       let owner =  owner();
        let  counter = deploy_contract(owner);

        start_cheat_caller_address(counter.contract_address, owner);
        counter.increase_count(10);
        assert_eq!(counter.get_count(), 10);

        counter.decrease_count(0);

        assert_eq!(counter.get_count(), 10,);
       
    }

    #[test]
    fn test_reset_count() {
        let owner = contract_address_const::<'owner'>();
        let counter = deploy_contract(owner);
        
        start_cheat_caller_address(counter.contract_address, owner);
        
        counter.reset_count();
        assert_eq!(counter.get_count(), 0);
        
        counter.increase_count(42);
        assert_eq!(counter.get_count(), 42);
        
        counter.reset_count();
        assert_eq!(counter.get_count(), 0);
        
        counter.reset_count();
        assert_eq!(counter.get_count(), 0);
    }


        #[test]
    #[should_panic(expected: "Only owner can change state")]
    fn test_reset_count_not_owner() {
        let owner = contract_address_const::<'owner'>();
        let counter = deploy_contract(owner);
        
        let attacker = attacker();
        start_cheat_caller_address(counter.contract_address, attacker);
        
        counter.reset_count(); 
    }
    
    #[test]
    fn test_transfer_ownership() {
        let owner = owner();
        let new_owner = new_owner();
        let counter = deploy_contract(owner);
        
        start_cheat_caller_address(counter.contract_address, owner);
        
        counter.transfer_ownership(new_owner);
        assert_eq!(counter.get_owner(), new_owner);
        
        // New owner should now have access
        start_cheat_caller_address(counter.contract_address, new_owner);
        counter.increase_count(5);
        assert_eq!(counter.get_count(), 5);
    }

     #[test]
    #[should_panic(expected: "Only owner can transfer")]
    fn test_transfer_ownership_not_owner() {
        let owner = owner();
        let counter = deploy_contract(owner);
        
        let attacker = attacker();
        start_cheat_caller_address(counter.contract_address, attacker);
        
        counter.transfer_ownership(attacker); // Should panic
    }

    }
