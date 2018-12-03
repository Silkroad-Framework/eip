pragma solidity ^0.5;

import "./Pausable.sol";


// 零身份合约
contract ZID is Pausable {

    // 每一个用户(个人，组织或设备)注册时，合约会在内部给TA生成一个ID，这个ID就是idCount. 同时idCount也表示当前有多少人注册。
    int256 private idCount = 1;
    // 每一个用户的所有地址(丢失或未丢失，主或备)都指向其ID。
    mapping (address => int256) private idIndex;
    // 每一个ID都指向一个地址数组。这个数组保存的是这个ID对应用户使用的所有地址，按照注册和挂失顺序保存。
    mapping (int256 => address[]) private addressChains;

    event LogAddNewID(address _operator, address _main, address _candidate);
    event LogZidReclaimed(address _operator, address _preMain, address _newMain, address _newCandidate);

    function getIsLost(address _address) public view returns (bool) {
        int256 index = idIndex[_address];
        if (index <= 0) {
            return false;    // 未注册地址
        }
        uint256 length = addressChains[index].length;
        // 如果不是当前的主地址也不是当前备用地址，那么表示是丢失了的。
        if (addressChains[index][length - 1] != _address &&
            addressChains[index][length - 2] != _address) {
            return true;
        } else {
            return false;
        }
    }

	// 注册新零身份并将备用零身份绑定到该新零身份
	// To register a new zero-identity and generates a new backup zero-identity
    function NewZidRegFrom(address _main, address _candidate) public {
        _NewZidRegFrom(_main, _candidate);
    }

	// 注册新零身份并将备用零身份绑定到该新零身份
	// To register a new zero-identity and generates a new backup zero-identity
    function NewZidReg(address _candidate) public {
        _NewZidRegFrom(msg.sender, _candidate);
    }

    //// 该接口用于测试  
    //function ZidReclaimedFrom(address _preMain, address _newMain, address _newCandidate) public {
    //    _ZidReclaimed(_preMain, _newMain, _newCandidate);
    //}

	// 零身份变更声明/挂失
	// Claims loss of an active zero-identity or change of an active zero-identity
    function ZidReclaimed(address _preMain, address _newCandidate) public {
        _ZidReclaimed(_preMain, msg.sender, _newCandidate);
    }

    function _NewZidRegFrom(address _main, address _candidate) private whenNotPaused {
        require(_main != address(0) && _candidate != address(0));
        require(_main != _candidate);
        // 确保两个地址都是未注册的。
        require(idIndex[_main] == 0 && idIndex[_candidate] == 0);

        // 两个地址都指向同一个ID，表示这个用户使用的地址。
        idIndex[_main] = idCount;
        idIndex[_candidate] = idCount;
        addressChains[idCount].push(_main);
        addressChains[idCount].push(_candidate);
        // 下一个注册用户是ID往上自增的。
        idCount++;

        emit LogAddNewID(msg.sender, _main, _candidate);
    }

    function _ZidReclaimed(address _preMain, address _newMain, address _newCandidate) private whenNotPaused {
        require(_newCandidate != address(0));
        require(_newMain != _newCandidate);
        // 确保已经注册过，并且是属于同一个人的。
        require(idIndex[_preMain] > 0 && idIndex[_newMain] > 0 && idIndex[_preMain] == idIndex[_newMain]);
        
        int256 index = idIndex[_preMain];
        uint256 length = addressChains[index].length;
        // 确保_newMain是当前备用地址。
        require(addressChains[index][length - 2] == _preMain);
        require(addressChains[index][length - 1] == _newMain);
        idIndex[_newCandidate] = index;
        addressChains[index].push(_newCandidate);

        emit LogZidReclaimed(msg.sender, _preMain, _newMain, _newCandidate);
    }
    
    function _ZidApproveClaimed(address _pre, address _newMain, address _newCandidate) internal whenNotPaused {
        require(_newCandidate != address(0));
        require(_newMain != _newCandidate);
        // 确保没有注册过，并且是属于同一个人的。
        int256 idx = idIndex[_pre];
        require(idx > 0 && idIndex[_newMain] == 0 && idIndex[_newCandidate] == 0 );
        
        
        idIndex[_newMain] = idx;
        idIndex[_newCandidate] = idx;
        addressChains[idx].push(_newMain);
        addressChains[idx].push(_newCandidate);
    }


	// 查询某个地址当前有效的零身份. 返回0表示没注册过。
	// Queries the current active Ethereum address according to an old identity. 
	// Return address Zero indicate the address has not been registered yet.
    function getActiveZid(address _address) public view returns (address) {
        int256 index = idIndex[_address];
        if (index <= 0) {
            return address(0);
        }
        uint256 length = addressChains[index].length;
        // 只有最后2个地址是表示未丢失的当前主地址和备用地址。
        return addressChains[index][length - 2];
    }

	// 查询某个零身份的备用零身份. 返回0表示没注册过。
	// Queries the backup zero-identity
	// Return address Zero indicate the address has not been registered yet.
    function getCurrentCandidate(address _address) public view returns (address) {
        int256 index = idIndex[_address];
        if (index <= 0) {
            return address(0);
        }
        uint256 length = addressChains[index].length;
        return addressChains[index][length - 1];
    }
    
    
    // 内部函数：取地址对应的id
    // 返回0表示未注册过
    function getIndex(address _address) internal view returns (int256) {
        return idIndex[_address];
    }
}