// @formatter:off
pragma ever-solidity >= 0.66.0;
// @formatter:on

library msg_flag {
    uint8 constant sender_pays_fees = 1;
    uint8 constant ignore_errors = 2;
    uint8 constant destroy_if_zero = 32;
    uint8 constant remaining_gas = 64;
    uint8 constant all_not_reserved = 128;
}
