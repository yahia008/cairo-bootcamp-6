use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256,
    );
}

#[starknet::interface]
pub trait IAdminRestricted<TContractState> {
    fn set_transfer_limit(ref self: TContractState, new_limit: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn revoke_transfers(ref self: TContractState);
    fn enable_transfers(ref self: TContractState);
    fn get_transfer_limit(self: @TContractState) -> u256;
    fn is_transfers_enabled(self: @TContractState) -> bool;
    fn admin_revoke_spender(
        ref self: TContractState, owner: ContractAddress, spender: ContractAddress,
    );
}

#[starknet::contract]
pub mod erc20 {
    use core::num::traits::{Bounded, Zero};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, contract_address_const, get_caller_address};

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        revoked_user: Map<ContractAddress, bool>,
        admin: ContractAddress,
        transfer_limit: u256,
        transfers_enabled: bool,
    }

    #[event]
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        TransferLimitUpdated: TransferLimitUpdated,
        TransfersRevoked: TransfersRevoked,
        TransfersEnabled: TransfersEnabled,
        Burn: Burn,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct TransferLimitUpdated {
        pub old_limit: u256,
        pub new_limit: u256,
        pub updated_by: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct TransfersRevoked {
        pub revoked_by: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct TransfersEnabled {
        pub enabled_by: ContractAddress,
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Burn {
        #[key]
        pub from: ContractAddress,
        pub value: u256,
        pub burned_by: ContractAddress,
    }

    mod Errors {
        pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
        pub const NOT_ADMIN: felt252 = 'ERC20: not admin';
        pub const TRANSFERS_DISABLED: felt252 = 'ERC20: transfers disabled';
        pub const EXCEEDS_MAX_LIMIT: felt252 = 'ERC20: exceeds max limit';
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
        pub const INVALID_LIMIT: felt252 = 'ERC20: limit must be >0';
        pub const BURN_AMOUNT_ZERO: felt252 = 'ERC20: burn amount >0';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
        pub const SPENDER_REVOKED: felt252 = 'ERC20: spender revoked';
        pub const ZERO_ADDRESS: felt252 = 'ERC20: zero address';
    }

    // Adjusted limit assuming 18 decimals for context, tweak as needed!
    const MAX_LIMIT: u256 = 10000_u256;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress,
        name: felt252,
        decimals: u8,
        initial_supply: u256,
        symbol: felt252,
        admin: ContractAddress,
    ) {
        assert(admin.is_non_zero(), Errors::ZERO_ADDRESS);
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.admin.write(admin);
        self.transfer_limit.write(MAX_LIMIT);
        self.transfers_enabled.write(true);
        self.mint(recipient, initial_supply);
    }

    #[abi(embed_v0)]
    impl IERC20Impl of super::IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }
        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }
        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self._validate_transfer(sender, recipient, amount);
            self._transfer(sender, recipient, amount);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let caller = get_caller_address();

            assert(!self.revoked_user.read(caller), Errors::SPENDER_REVOKED);

            self._validate_transfer(sender, recipient, amount);
            self.spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(!self.revoked_user.read(spender), Errors::SPENDER_REVOKED);
            assert(amount != 0, 'amount cant be zero');
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256,
        ) {
            self._only_admin();
            let caller = get_caller_address();
            assert(!self.revoked_user.read(spender), Errors::SPENDER_REVOKED);
            let current_allowance = self.allowances.read((caller, spender));
            self.approve_helper(caller, spender, current_allowance + added_value);
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256,
        ) {
            self._only_admin();
            let caller = get_caller_address();
            let current_allowance = self.allowances.read((caller, spender));
            assert(current_allowance >= subtracted_value, Errors::INSUFFICIENT_ALLOWANCE);
            self.approve_helper(caller, spender, current_allowance - subtracted_value);
        }
    }

    #[abi(embed_v0)]
    impl IAdminRestrictedImpl of super::IAdminRestricted<ContractState> {
        fn set_transfer_limit(ref self: ContractState, new_limit: u256) {
            self._only_admin();
            assert(new_limit > 0, Errors::INVALID_LIMIT);
            //assert(new_limit <= MAX_LIMIT, Errors::EXCEEDS_MAX_LIMIT);

            let old_limit = self.transfer_limit.read();
            self.transfer_limit.write(new_limit);

            self
                .emit(
                    TransferLimitUpdated { old_limit, new_limit, updated_by: get_caller_address() },
                );
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self._only_admin();
            assert(account.is_non_zero(), Errors::BURN_FROM_ZERO);
            assert(amount > 0, Errors::BURN_AMOUNT_ZERO);

            let balance = self.balances.read(account);
            assert(balance >= amount, Errors::INSUFFICIENT_BALANCE);

            self.balances.write(account, balance - amount);
            self.total_supply.write(self.total_supply.read() - amount);

            let zero_address = Zero::zero();
            let zero_balance = self.balances.read(zero_address);
            self.balances.write(zero_address, zero_balance + amount);

            self.emit(Burn { from: account, value: amount, burned_by: get_caller_address() });
            self.emit(Transfer { from: account, to: zero_address, value: amount });
        }

        fn revoke_transfers(ref self: ContractState) {
            self._only_admin();
            assert(self.transfers_enabled.read() == true, 'transfer not enabled');
            self.transfers_enabled.write(false);
            self.emit(TransfersRevoked { revoked_by: get_caller_address() });
        }

        fn enable_transfers(ref self: ContractState) {
            self._only_admin();
            assert(self.transfers_enabled.read() == false, 'transfer enabled');
            self.transfers_enabled.write(true);
            self.emit(TransfersEnabled { enabled_by: get_caller_address() });
        }

        fn get_transfer_limit(self: @ContractState) -> u256 {
            self.transfer_limit.read()
        }
        fn is_transfers_enabled(self: @ContractState) -> bool {
            self.transfers_enabled.read()
        }

        fn admin_revoke_spender(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress,
        ) {
            self._only_admin();
            assert(owner.is_non_zero() && spender.is_non_zero(), Errors::ZERO_ADDRESS);

            let is_already_revoked = self.revoked_user.read(spender);
            assert(!is_already_revoked, 'ERC20: already revoked');

            self.approve_helper(owner, spender, 0);
            self.revoked_user.write(spender, true);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _only_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), Errors::NOT_ADMIN);
        }

        fn _validate_transfer(
            self: @ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
        ) {
            assert(sender.is_non_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(recipient.is_non_zero(), Errors::TRANSFER_TO_ZERO);
            assert(self.transfers_enabled.read(), Errors::TRANSFERS_DISABLED);

            let current_limit = self.transfer_limit.read();
            assert(amount <= current_limit, Errors::EXCEEDS_MAX_LIMIT);

            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, Errors::INSUFFICIENT_BALANCE);
        }

        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            // assert(self.transfers_enabled.read() == true, 'transfer is not enable');
            assert(sender.is_non_zero(), Errors::ZERO_ADDRESS);
            assert(recipient.is_non_zero(), Errors::ZERO_ADDRESS);
            let sender_balance = self.balances.read(sender);
            self.balances.write(sender, sender_balance - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance != Bounded::MAX {
                assert(current_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
                self.allowances.write((owner, spender), current_allowance - amount);
            }
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            assert(spender.is_non_zero(), Errors::APPROVE_TO_ZERO);
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(recipient.is_non_zero(), Errors::MINT_TO_ZERO);
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self
                .emit(
                    Transfer { from: contract_address_const::<0>(), to: recipient, value: amount },
                );
        }
    }
}
