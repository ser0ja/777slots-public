// @formatter:off
pragma ever-solidity >= 0.66.0;
// @formatter:on

pragma AbiHeader pubkey;
pragma AbiHeader time;
pragma AbiHeader expire;

import "./libraries/index.sol";

contract Root {
    // uint64 static public _random;
    
    uint64 private version;
    address private owner;
    uint64 private deploy_time;
    uint64 private upgrade_time;
    string[20] private symbol_db = [
        'cherry', 'bar', 'bell', 'clover', 'clubs', 
        'crown', 'crystal', 'seven', 'diamonds', 'dollar',
        'grape', 'hearts', 'horseshoe', 'win', 'lemon',
        'plum', 'question', 'spades', 'star', 'watermelon'
    ];
    uint8[20] private symbols;
    uint8[3] private rates = [1, 5, 10];
    uint8 private ratio =  5; // 1 / 5 = 0.2 -> 1920 EVER
    uint128[3] private jackpots;

    mapping(uint8 => uint128) private jackpot_db;

    struct Args {
        uint8[] arg0;
        uint128[] arg1;
        uint256[] arg2;
        bool[] arg3;
        address[] arg4;
        string[] arg5;
    }
    mapping(uint8 => Args) private args_db;

    struct Player {
        uint256 pubkey;
        uint128 balance;
        uint8 status; // 0 - normal, 1 - blacklist, 2 - owner
        uint8 rate;
        uint8[3] symbols;
    }
    mapping(address => Player) private player_db;

    constructor(address _owner, uint64 _deploy_time) public {
        require(tvm.pubkey() != 0, errors.zero_pubkey);
        require(tvm.pubkey() == msg.pubkey(), errors.diff_pubkey);
        tvm.accept();

        owner = _owner;
        deploy_time = _deploy_time;

        jackpot_init();
        uint128 init_balance = jackpot_balance() + players_balance();
        require(balance() >= gas.root_initial_balance + init_balance, errors.root_deploy_balance_too_low);

        tvm.rawReserve(gas.root_initial_balance + init_balance, 0);
        owner.transfer({value : 0, flag : msg_flag.all_not_reserved + msg_flag.ignore_errors, bounce : false});
    }

    modifier check_owner {
        require(msg.pubkey() == tvm.pubkey(), errors.diff_pubkey);
        tvm.accept();
        _;
    }

    function balance() private pure returns (uint128) {
        return address(this).balance;
    }

    function jackpot() external view returns (mapping(uint8 => uint128)) {
        return jackpot_db;
    }

    function jackpot_by_rate(uint8 _rate) external view returns (uint128) {
        return jackpot_db[_rate];
    }

    function jackpot_balance() private view returns (uint128) {
        uint128 amount = uint128(0);
        for((, uint128 a) : jackpot_db){
            amount += a;
        }
        return amount;
    }

    function jackpot_init() private {
        for (uint8 i=0; i < rates.length; ++i) {
            uint128 rate = uint128(rates[i]) * uint128(1e11);
            jackpot_db.add(rates[i], rate + (rate / ratio));
        }
    }

    function jackpot_reset() external check_owner returns (mapping(uint8 => uint128)) {
        jackpot_init();
        return jackpot_db;
    }

    function set_blacklist(address _player) external check_owner returns (bool) {
        player_db[_player].status = 1;
        return true;
    }

    function remove_blacklist(address _player) external check_owner returns (bool) {
        player_db[_player].status = 0;
        return true;
    }

    function symbols_list() external view returns (string[]) {
        return symbol_db;
    }

    function players() external view check_owner returns (mapping(address => Player)) {
        return player_db;
    }

    function player(address _player) external view check_owner returns (Player) {
        return player_db[_player];
    }

    function players_balance() private view returns (uint128) {
        uint128 amount = uint128(0);
        for((, Player p) : player_db){
            amount += p.balance;
        }
        return amount;
    }

    function player_balance(address _player) public view returns (uint128) {
        return player_db[_player].balance;
    }

    function deposit(uint256 _pubkey) public {
        address _player = msg.sender;
        require(_player != address(0), errors.msg_not_address);
        require(msg.value != uint128(0), errors.msg_not_value);
        Player p0 = player_db[_player];
        require(p0.status != 1, errors.player_blacklist);
        if(p0.pubkey == uint256(0)){
            p0.pubkey = _pubkey;
            if(_player == owner){
                p0.status = 2;
            }
        }
        p0.balance += msg.value;
        player_db[_player] = p0;
    }

    function withdraw(address _player, uint128 _amount) external returns (uint128) {
        uint256 _pubkey = msg.pubkey();
        require(_pubkey != uint256(0), errors.msg_not_pubkey);
        require(_amount > uint128(0), errors.withdraw_not_amount);
        Player p0 = player_db[_player];
        require(p0.status != 1, errors.player_blacklist);
        require(p0.pubkey == _pubkey, errors.msg_pubkey_not_player_pubkey);
        require(p0.balance >= _amount, errors.player_balance_less_amount);
        tvm.accept();
        _player.transfer({value : _amount, flag : msg_flag.remaining_gas, bounce : true});
        p0.balance -= _amount;
        player_db[_player] = p0;
        return p0.balance;
    }

    function calc_chance(uint8[3] _chance, uint128 _balance, uint8 _rate) private returns(uint128) {
        // 0 - 'cherry'
        // 1 - 'seven'
        uint128 rate_to_ever = uint128(_rate) * uint128(1e9);
        uint128 half_rate_to_ever = rate_to_ever / 2;
        _balance -= rate_to_ever;

        if(_chance[0] == _chance[1] && _chance[1] == _chance[2] && _chance[2] == uint8(7)){
            _balance += jackpot_db[_rate];
            jackpot_db[_rate] = 0;

        }else if(_chance[0] == _chance[1] && _chance[1] == _chance[2] && _chance[2] == uint8(13)){
            _balance += (rate_to_ever * 10);
            jackpot_db[_rate] -= (half_rate_to_ever * 10);

        }else if(_chance[0] == _chance[1] && _chance[1] == _chance[2]){
            _balance += (rate_to_ever * 8);
            jackpot_db[_rate] -= (half_rate_to_ever * 8);

        }else if((_chance[0] == _chance[1] || _chance[1] == _chance[2]) && (_chance[0] == uint8(13) || _chance[1] == uint8(13) || _chance[2] == uint8(13))){
            _balance += (rate_to_ever * 6);
            jackpot_db[_rate] -= (half_rate_to_ever * 6);

        }else if((_chance[0] == _chance[1] || _chance[1] == _chance[2]) && (_chance[0] == uint8(0) || _chance[1] == uint8(0) || _chance[2] == uint8(0))){
            _balance += (rate_to_ever * 5);
            jackpot_db[_rate] -= (half_rate_to_ever * 5);

        }else if(_chance[0] == _chance[1] || _chance[1] == _chance[2]){
            _balance += (rate_to_ever * 4);
            jackpot_db[_rate] -= (half_rate_to_ever * 4);

        }else if(_chance[0] == uint8(0) || _chance[1] == uint8(0)|| _chance[2] == uint8(0)){
            _balance += rate_to_ever;
            jackpot_db[_rate] -= half_rate_to_ever;

        }else{
            jackpot_db[_rate] += half_rate_to_ever;
        }
        return _balance;
    }

    function rnd_num() private view returns (uint8) {
        tvm.accept();
        rnd.shuffle();
        return symbol_db.length > 0 ? rnd.next(uint8(symbol_db.length)) : 0;
    }

    function spin(address _player, uint8 _rate) external returns (uint8[]) {
        bool in_rates = false;
        for (uint8 rate : rates) {
            if (rate == _rate) {
                in_rates = true;
                break;
            }
        }
        require(in_rates, errors.spin_rates_error);
        require(_player != address(0), errors.arg_player_not_address);
        uint128 rate_to_ever = uint128(_rate) * uint128(1e9);
        Player p0 = player_db[_player];
        require(p0.status != 1, errors.player_blacklist);
        require(p0.pubkey != uint256(0), errors.player_not_pubkey);
        require(p0.balance >= rate_to_ever, errors.player_balance_less_amount);

        uint8[3] chance = [rnd_num(), rnd_num(), rnd_num()];
        p0.balance = calc_chance(chance, p0.balance, _rate);
        p0.symbols = chance;
        p0.rate = _rate;
        player_db[_player] = p0;
        return chance;
    }

    function transfer_all() external view check_owner returns (bool){
        tvm.rawReserve(0, 0);
        owner.transfer({value : 0, flag : msg_flag.all_not_reserved + msg_flag.ignore_errors, bounce : false});
    }

    function upgrade(TvmCell _new_code, uint64 _upgrade_time, TvmCell _args) public check_owner {
        uint128 game_balance = jackpot_balance() + players_balance();
        require(balance() >= gas.root_upgrade_balance + game_balance, errors.root_upgrade_balance_too_low);

        tvm.rawReserve(gas.root_upgrade_balance + game_balance, 0);
        owner.transfer({value : 0, flag : msg_flag.all_not_reserved + msg_flag.ignore_errors, bounce : false});

        TvmBuilder data;
        data.store(_upgrade_time);

        data.storeRef(_args);

        tvm.setcode(_new_code);
        tvm.setCurrentCode(_new_code);
        onCodeUpgrade(data.toCell());
    }

    function onCodeUpgrade(TvmCell params) private {
        // tvm.resetStorage();

        TvmSlice data = params.toSlice();
        upgrade_time = data.decode(uint64);

        TvmSlice args = data.loadRefAsSlice();
        args_db = args.decode(mapping(uint8 => Args));

        ++version;
    }
}
