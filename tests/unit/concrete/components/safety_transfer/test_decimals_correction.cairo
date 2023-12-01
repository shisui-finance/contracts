use starknet::{ContractAddress, contract_address_const,};
use shisui::components::safety_transfer::{
    ISafetyTransfer, ISafetyTransferDispatcher, ISafetyTransferDispatcherTrait,
    SafetyTransferComponent
};
use shisui::mocks::safety_transfer_mock::SafetyTransferMockContract;

const amount: u256 = 1000000000000000001;
const amount_12Dec: u256 = 1000000000000;
const amount_16Dec: u256 = 10000000000000000;
const amount_20Dec: u256 = 100000000000000000100;

type TestingState =
    SafetyTransferComponent::ComponentState<SafetyTransferMockContract::ContractState>;

impl TestingStateDefault of Default<TestingState> {
    fn default() -> TestingState {
        SafetyTransferComponent::component_state_for_testing()
    }
}

#[generate_trait]
impl TestingStateImpl of TestingStateTrait {
    fn init() -> TestingState {
        let mut safety_transfer: TestingState = Default::default();
        safety_transfer
    }
}

// This tests check decimal correction with a token having 16 dec using component logic
// It calls safety_transfer.decimals_correction()
// The test expects the call to succeed without error
#[test]
fn given_normal_conditions_when_calling_safety_transfer_with_16_dec_component_then_works() {
    let token_address: ContractAddress = tests::tests_lib::deploy_erc20_mock(16);
    let safety_transfer: TestingState = TestingStateTrait::init();
    let result = safety_transfer.decimals_correction(token_address, amount);
    assert(result == amount_16Dec, 'Error on 16 dec correction');
}

// This tests check decimal correction with a token having 16 dec using mock contract deployment
// It calls safety_transfer.decimals_correction()
// The test expects the call to succeed without error
#[test]
fn given_normal_conditions_when_calling_safety_transfer_with_16_dec_then_works() {
    let (safety_transfer, erc20_token_address) = init_mock_contract(16);
    let result = safety_transfer.decimals_correction(erc20_token_address, amount);
    assert(result == amount_16Dec, 'Error on 16 dec correction');
}

// This tests check decimal correction with a token having 18 dec using mock contract deployment
// It calls safety_transfer.decimals_correction()
// The test expects the call to succeed without error
#[test]
fn given_normal_conditions_when_calling_safety_transfer_with_18_dec_then_works() {
    let (safety_transfer, erc20_token_address) = init_mock_contract(18);
    let result = safety_transfer.decimals_correction(erc20_token_address, amount);
    assert(result == amount, 'Error on 18 dec correction');
}

// This tests check decimal correction with a token having 20 dec using mock contract deployment
// It calls safety_transfer.decimals_correction()
// The test expects the call to succeed without error
#[test]
fn given_normal_conditions_when_calling_safety_transfer_with_20_dec_then_works() {
    let (safety_transfer, erc20_token_address) = init_mock_contract(20);
    let result = safety_transfer.decimals_correction(erc20_token_address, amount);
    assert(result == amount_20Dec, 'Error on 20 dec correction');
}

// This tests check decimal correction with an amount set to 0
// It calls safety_transfer.decimals_correction()
// The test expects the call to succeed without error
#[test]
fn given_normal_conditions_when_calling_safety_transfer_with_0_amount_then_works() {
    let (safety_transfer, erc20_token_address) = init_mock_contract(18);
    let result = safety_transfer.decimals_correction(erc20_token_address, 0);
    assert(result == 0, 'Error when passing 0 amount');
}

// This tests check decimal correction with a token address set to 0
// It calls safety_transfer.decimals_correction()
// The test expects the call to panic with error Token address is 0
#[test]
#[should_panic(expected: ('Token address is 0',))]
fn given_token_address_0_then_it_fails() {
    let (safety_transfer, erc20_token_address) = init_mock_contract(18);
    let token_address: ContractAddress = contract_address_const::<0>();
    let result = safety_transfer.decimals_correction(token_address, 0);
}

// function to deploy mock contract
fn init_mock_contract(decimals: u8) -> (ISafetyTransferDispatcher, ContractAddress) {
    let erc_20_token_address: ContractAddress = tests::tests_lib::deploy_erc20_mock(decimals);
    let safety_transfer_address: ContractAddress = tests::tests_lib::deploy_safety_transfer_mock();
    let safety_transfer = ISafetyTransferDispatcher { contract_address: safety_transfer_address };
    (safety_transfer, erc_20_token_address)
}
