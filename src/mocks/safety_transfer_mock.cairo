//! Mock Contract referencing SafetyTransferComponent

#[starknet::contract]
mod SafetyTransferMockContract {
    // *************************************************************************
    //                                  IMPORTS
    // *************************************************************************
    use shisui::components::safety_transfer::{SafetyTransferComponent};
    use starknet::{ContractAddress};

    // *************************************************************************
    //                  Component
    // *************************************************************************
    component!(path: SafetyTransferComponent, storage: mock_storage, event: MockEvent);

    #[abi(embed_v0)]
    impl SafetyTransferImpl =
        SafetyTransferComponent::SafetyTransferImpl<ContractState>;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        #[substorage(v0)]
        mock_storage: SafetyTransferComponent::Storage
    }

    // *************************************************************************
    //                              EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MockEvent: SafetyTransferComponent::Event
    }
}
