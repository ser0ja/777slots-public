// @formatter:off
pragma ever-solidity >=0.66.0;

// @formatter:on

library errors {
	uint16 constant not_owner = 1000;
	uint16 constant not_root = 1010;

	uint16 constant zero_pubkey = 1100;
	uint16 constant diff_pubkey = 1101;
	uint16 constant root_deploy_balance_too_low = 1102;
	uint16 constant root_upgrade_balance_too_low = 1103;

	uint16 constant msg_not_address = 1200;
	uint16 constant msg_not_pubkey = 1201;
	uint16 constant msg_not_value = 1202;

	uint16 constant player_blacklist = 1300;
	uint16 constant player_not_pubkey = 1301;
	uint16 constant player_balance_less_amount = 1302;
	uint16 constant spin_rates_error = 1303;
	uint16 constant msg_pubkey_not_player_pubkey = 1304;
	uint16 constant arg_player_not_address = 1305;
	uint16 constant withdraw_not_amount = 1306;
}
