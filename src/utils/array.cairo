use starknet::{ContractAddress, StorageBaseAddress, SyscallResult, Store};

impl StoreContractAddressArray of Store<Array<ContractAddress>> {
    fn read(
        address_domain: u32, base: StorageBaseAddress
    ) -> SyscallResult<Array<ContractAddress>> {
        StoreContractAddressArray::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<ContractAddress>
    ) -> SyscallResult<()> {
        StoreContractAddressArray::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Array<ContractAddress>> {
        let mut arr: Array<ContractAddress> = array![];

        // Read the stored array's length. If the length is superior to 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset).unwrap();
        offset += 1;

        // Sequentially read all stored elements and append them to the array.
        let exit = len + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<ContractAddress>::read_at_offset(address_domain, base, offset)
                .unwrap();
            arr.append(value);
            offset += Store::<ContractAddress>::size();
        };

        // Return the array.
        Result::Ok(arr)
    }

    fn write_at_offset(
        address_domain: u32,
        base: StorageBaseAddress,
        mut offset: u8,
        mut value: Array<ContractAddress>
    ) -> SyscallResult<()> {
        // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len);
        offset += 1;

        // Store the array elements sequentially
        loop {
            match value.pop_front() {
                Option::Some(element) => {
                    Store::<ContractAddress>::write_at_offset(address_domain, base, offset, element)
                        .unwrap();
                    offset += Store::<ContractAddress>::size();
                },
                Option::None(_) => { break Result::Ok(()); }
            };
        }
    }

    fn size() -> u8 {
        255
    }
}


impl StoreContractAddressSpan of Store<Span<ContractAddress>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Span<ContractAddress>> {
        StoreContractAddressSpan::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Span<ContractAddress>
    ) -> SyscallResult<()> {
        StoreContractAddressSpan::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Span<ContractAddress>> {
        let mut arr: Array<ContractAddress> = ArrayTrait::new();

        // Read the stored array's length. If the length is superior to 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset)
            .expect('Storage Span too large');
        offset += 1;

        // Sequentially read all stored elements and append them to the array.
        let exit = len + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<ContractAddress>::read_at_offset(address_domain, base, offset)
                .unwrap();
            arr.append(value);
            offset += Store::<ContractAddress>::size();
        };

        // Return the array.
        Result::Ok(arr.span())
    }

    fn write_at_offset(
        address_domain: u32,
        base: StorageBaseAddress,
        mut offset: u8,
        mut value: Span<ContractAddress>
    ) -> SyscallResult<()> {
        // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len);
        offset += 1;

        // Store the array elements sequentially
        loop {
            match value.pop_front() {
                Option::Some(element) => {
                    Store::<
                        ContractAddress
                    >::write_at_offset(address_domain, base, offset, *element);
                    offset += Store::<felt252>::size();
                },
                Option::None(_) => { break Result::Ok(()); }
            };
        }
    }

    fn size() -> u8 {
        255 * Store::<felt252>::size()
    }
}


impl StoreU256Array of Store<Array<u256>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<u256>> {
        StoreU256Array::read_at_offset(address_domain, base, 0)
    }

    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Array<u256>
    ) -> SyscallResult<()> {
        StoreU256Array::write_at_offset(address_domain, base, 0, value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8
    ) -> SyscallResult<Array<u256>> {
        let mut arr: Array<u256> = array![];

        // Read the stored array's length. If the length is superior to 255, the read will fail.
        let len: u8 = Store::<u8>::read_at_offset(address_domain, base, offset).unwrap();
        offset += 1;

        // Sequentially read all stored elements and append them to the array.
        let exit = len + offset;
        loop {
            if offset >= exit {
                break;
            }

            let value = Store::<u256>::read_at_offset(address_domain, base, offset).unwrap();
            arr.append(value);
            offset += Store::<u256>::size();
        };

        // Return the array.
        Result::Ok(arr)
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, mut offset: u8, mut value: Array<u256>
    ) -> SyscallResult<()> {
        // Store the length of the array in the first storage slot.
        let len: u8 = value.len().try_into().expect('Storage - Span too large');
        Store::<u8>::write_at_offset(address_domain, base, offset, len);
        offset += 1;

        // Store the array elements sequentially
        loop {
            match value.pop_front() {
                Option::Some(element) => {
                    Store::<u256>::write_at_offset(address_domain, base, offset, element).unwrap();
                    offset += Store::<u256>::size();
                },
                Option::None(_) => { break Result::Ok(()); }
            };
        }
    }

    fn size() -> u8 {
        255
    }
}
