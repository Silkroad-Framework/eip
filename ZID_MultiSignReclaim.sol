pragma solidity ^0.5;

import "./ZID.sol";

// 多重签名取回机制的零身份
// 执行逻辑：
// 可以设置见证人。
// 可以设置足够多的见证人。并设置达到多少人同意，就可以重新设置新备用身份。
// 当足够多的人设置同意之后，见证人中之一就可以设置新的备用身份。
contract ZID_MultiSignReclaim is ZID {
    
    struct MultiSignData
    {
        // 见证人id(由getIndex取得) => 执行情况
        // 执行情况: 0 该id无效。1 该id被授权投票。2 该id已投票。
        //mapping( int256 => int256 ) mapSign;
        mapping( int256 => address ) mapSign;
        
        // 有多少人可以来执行( 是 mapSign 里有效数目 )
        // 肯定大于 0
        uint256 uiSignerCount;
        
        // 达到多少人执行就有效
        // 肯定大于 0
        uint256 uiEffectiveCount;
        
        // 当前有多少人同意执行
        uint256  uiAgreeCount;
        
    }
    
    //  备用身份=>多重签名数据
    mapping ( address => MultiSignData ) public mapMultiSign;
    
    event evtAddSigner(address indexed _operator, address indexed _signer, bool indexed bAdd, uint256 uiFinalSignerCount, uint256 uiFinalAgreeCount  );
    event evtSetMinCount( address indexed _operator, uint uiFinalMinEffectiveCount, uint256 uiFinalAgreeCount );
    event evtSignerApprove( address indexed _signerOperator, address indexed _approveForWho, uint256 uiFinalMinEffectiveCount, uint256 uiFinalAgreeCount  ) ;
    event evtSignerSetNewAddr( address indexed _operator, address addrLostIWillApprove, address _new_main, address _new_candidate );
    
    
    // 设置见证人
    // 见证人地址必须在本合约里有过注册
    // 参数 bAdd  如果为false，则将原有见证人删除
    function SetSigner( address addrSigner, bool bAdd ) public whenNotPaused
    {
        int256 idx = getIndex( addrSigner ) ;
        require( idx > 0 );
        
        require( idx != getIndex(msg.sender) );
        
        address addrCandidate = getCurrentCandidate( msg.sender );
        require( addrCandidate != address(0) );
        
        address addr = mapMultiSign[addrCandidate].mapSign[ idx ];
        if( bAdd )
        {
            if( addr == address(0) )
            {
                ++(mapMultiSign[addrCandidate].uiSignerCount);
                
                // Set to 1 indicate that the address is approved.
                mapMultiSign[addrCandidate].mapSign[ idx ] = address(1);
            }
        }
        else
        {
            if( addr != address(0) )
            {
                --(mapMultiSign[addrCandidate].uiSignerCount);
                
                if( addr != address(1) )
                {
                    --(mapMultiSign[addrCandidate].uiAgreeCount);
                }
                mapMultiSign[addrCandidate].mapSign[ idx ] = address(0);
            }
        }
        
        emit evtAddSigner( msg.sender, addrSigner, bAdd, mapMultiSign[addrCandidate].uiSignerCount, mapMultiSign[addrCandidate].uiAgreeCount );
    }
    
    // 设置最少同意人数
    function SetMinAgreeCount( uint256 uiMinCount ) public whenNotPaused
    {
        address addrCandidate = getCurrentCandidate( msg.sender );
        require( addrCandidate != address(0) );
        
        mapMultiSign[ addrCandidate ].uiEffectiveCount = uiMinCount;
        
        emit evtSetMinCount( msg.sender, mapMultiSign[ addrCandidate ].uiEffectiveCount, mapMultiSign[ addrCandidate ].uiAgreeCount );
    }
    
    // 见证人同意为某个遗失的地址做担保
    function SignerApprove( address addrLostIWillApprove ) public whenNotPaused
    {
        int256 idx = getIndex( msg.sender ) ;
        require( idx > 0 );
        
        address addrCandidate = getCurrentCandidate( addrLostIWillApprove );
        require( addrCandidate != address(0) );
        
        address addr = mapMultiSign[addrCandidate].mapSign[idx];
        require( addr != address(0) );
        if( addr == address(1) )
        {
            mapMultiSign[addrCandidate].mapSign[idx] = msg.sender;
            ++(mapMultiSign[addrCandidate].uiAgreeCount);
            
            emit evtSignerApprove(msg.sender, addrLostIWillApprove, mapMultiSign[addrCandidate].uiEffectiveCount, mapMultiSign[addrCandidate].uiAgreeCount  );
        }
    }
    
    
    // 见证人重新为某个地址设置当前身份，以及备用身份
    function SignerSetNewAddr( address addrLostIWillApprove, address _new_main, address _new_candidate ) public whenNotPaused returns(int256)
    {
        int256 idx = getIndex( msg.sender ) ;
        //require( idx > 0 );
        if( idx <= 0 )
        {
            return 1;
        }
        
        address addrCandidate = getCurrentCandidate( addrLostIWillApprove );
        //require( addrCandidate != address(0) );
        if( addrCandidate == address(0) )
        {
            return 2;
        }
        
        address addr = mapMultiSign[addrCandidate].mapSign[idx];
        //require( addr != address(0) );
        if( addr == address(0) )
        {
            return 3;
        }
        
        uint256 uiMinCount = mapMultiSign[addrCandidate].uiEffectiveCount;
        //require( uiMinCount > 0 );
        //require(   mapMultiSign[addrCandidate].uiAgreeCount >= uiMinCount );
        if( uiMinCount == 0 )
        {
            return 4;
        }
        if( mapMultiSign[addrCandidate].uiAgreeCount < uiMinCount )
        {
            return 5;
        }
        
        
        _ZidApproveClaimed( addrLostIWillApprove, _new_main, _new_candidate );
        
        // 一旦设置，就将原有同意次数清零
        mapMultiSign[addrCandidate].uiAgreeCount = 0;
        
        emit evtSignerSetNewAddr( msg.sender, addrLostIWillApprove, _new_main, _new_candidate );
        return 0;
    }
    
    
    

}
