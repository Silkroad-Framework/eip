pragma solidity ^0.5;

import "./ZID.sol";

// 多重签名取回机制的零身份
// 执行逻辑：
// 可以设置见证人。
// 可以设置足够多的见证人。并设置达到多少人同意，就可以重新设置新备用身份。
// 当足够多的人设置同意之后，见证人中之一就可以设置新的备用身份。
contract ZID_MultiSignReclaim is ZID {
    
    // 用户授权哪些人可以签名投票
    struct MultiSignApproveData
    {
        // 见证人id(由getIndex取得) => 执行情况
        // 现在改用address来做索引，左边是授权签名者的索引（在本系统中的索引），右边是签名授权状态：true为已授权        
        mapping( address => bool ) mapSign;
        
        // 有多少人可以来执行( 是 mapSign 里有效数目 )
        // 肯定大于 0
        uint256 uiSignerCount;
        
        // 达到多少人执行就有效
        // 肯定大于 0
        uint256 uiEffectiveCount;
                
    }    
    // 备用身份=>多重签名数据
    // 左边是用户的索引（现在改为索引也是地址，不是int）
    mapping ( address => MultiSignApproveData ) public mapMultiSignApprove;
    
    
    
    // 哪些人已经签名投票
    struct MultiSignResultData
    {
    	// 左边是投票者的地址，右边是是否已投票
    	mapping( address => bool ) mapSign;
    	// 投票总人数
    	uint256 uiAgreeCount;
    }
    // 左边是当前的备用地址，右边是已投票状态
    mapping( address => MultiSignResultData ) public mapMultiSignResult;
    
    
    
    event evtAddSigner(address indexed _operator, address indexed _signer, bool indexed bAdd, uint256 uiFinalSignerCount, uint uiFinalMinEffectiveCount, uint256 uiFinalAgreeCount );
    event evtSetMinCount( address indexed _operator, uint256 uiFinalSignerCount, uint uiFinalMinEffectiveCount, uint256 uiFinalAgreeCount );
    event evtSignerApprove( address indexed _signerOperator, address indexed _approveForWho, uint256 uiFinalSignerCount, uint uiFinalMinEffectiveCount, uint256 uiFinalAgreeCount ) ;
    event evtSignerSetNewAddr( address indexed _operator, address addrLostIWillApprove, address _new_main, address _new_candidate );
    
    
    // 设置见证人
    // 见证人地址必须在本合约里有过注册
    // 参数 bAdd  如果为false，则将原有见证人删除
    function SetSigner( address addrSigner, bool bAdd ) public whenNotPaused
    {        
        address idxSigner = getIndex( addrSigner ) ;
        require( idxSigner != address(0) );
        
        address myIdx = getIndex( msg.sender );
        require( myIdx != address(0) );
        require( idxSigner != myIdx );
        
        address addrCandidate = _getCurrentCandidate( myIdx );
        // 问题：是否只能由备用身份来设置签名者
        //  如果不需要，只要屏蔽下面这句。
        require( addrCandidate == msg.sender );
                      
        if( bAdd )
        {
            if( !(mapMultiSignApprove[myIdx].mapSign[ idxSigner ]) )
            {
            	// 该人还没设定投票权
              ++(mapMultiSignApprove[myIdx].uiSignerCount);
            	mapMultiSignApprove[myIdx].mapSign[ idxSigner ] = true;
            	
            	emit evtAddSigner( msg.sender, addrSigner, bAdd, 
        				mapMultiSignApprove[myIdx].uiSignerCount, mapMultiSignApprove[myIdx].uiEffectiveCount, mapMultiSignResult[addrCandidate].uiAgreeCount );
            }
        }
        else
        {
            if( mapMultiSignApprove[myIdx].mapSign[ idxSigner ] )
            {
            	// 该人已经有投票权
            	--(mapMultiSignApprove[myIdx].uiSignerCount);
            	mapMultiSignApprove[myIdx].mapSign[ idxSigner ] = false;
                
            	if( mapMultiSignResult[addrCandidate].mapSign[ idxSigner ] )
            	{
            		mapMultiSignResult[addrCandidate].mapSign[ idxSigner ] = false;
            		--(mapMultiSignResult[addrCandidate].uiAgreeCount);            		
            	}
            	
            	emit evtAddSigner( msg.sender, addrSigner, bAdd, 
        				mapMultiSignApprove[myIdx].uiSignerCount, mapMultiSignApprove[myIdx].uiEffectiveCount, mapMultiSignResult[addrCandidate].uiAgreeCount );
            }
        }        
    }
    
    // 设置最少同意人数
    function SetMinAgreeCount( uint256 uiMinCount ) public whenNotPaused
    {        
        address myIdx = getIndex( msg.sender );
        require( myIdx != address(0) );
        
        mapMultiSignApprove[ myIdx ].uiEffectiveCount = uiMinCount;
        
        address addrCandidate = _getCurrentCandidate( myIdx );
        
        // 问题：是否只能由备用身份来设置最小同意数目
        //  如果不需要，只要屏蔽下面这句。
        require( addrCandidate == msg.sender );
        
        
        emit evtSetMinCount( msg.sender, 
        		mapMultiSignApprove[myIdx].uiSignerCount, mapMultiSignApprove[myIdx].uiEffectiveCount, mapMultiSignResult[addrCandidate].uiAgreeCount );
    }
    
    // 见证人同意为某个遗失的地址做担保
    function SignerApprove( address addrLostIWillApprove ) public whenNotPaused
    {
        address myIdx = getIndex( msg.sender );
        require( myIdx != address(0) );
        
        address lostIdx = getIndex( addrLostIWillApprove );
        require( lostIdx != address(0) );
        
        bool bApproved = mapMultiSignApprove[lostIdx].mapSign[myIdx];
        // 必须被授权过
        require( bApproved );
        
        // 问题：签名者是否必须是当前身份、或备用身份（不允许用过期的老身份）
        address addrMyActiveZid = _getActiveZid(myIdx);
        address addrMyCandidate = _getCurrentCandidate(myIdx);
        require( addrMyActiveZid == msg.sender || addrMyCandidate == msg.sender );                
        
        address addrCandidate = _getCurrentCandidate( lostIdx ); 
        bool bSigned = mapMultiSignResult[addrCandidate].mapSign[myIdx];
        if( !bSigned )
        {
        	// 如果没投过票，现在投票
            mapMultiSignResult[addrCandidate].mapSign[myIdx] = true;
            ++(mapMultiSignResult[addrCandidate].uiAgreeCount);
            
            emit evtSignerApprove(msg.sender, addrLostIWillApprove, 
            		mapMultiSignApprove[lostIdx].uiSignerCount, mapMultiSignApprove[lostIdx].uiEffectiveCount, mapMultiSignResult[addrCandidate].uiAgreeCount
             	);
        }
    }
    
    
    // 见证人重新为某个地址设置当前身份，以及备用身份
    function SignerSetNewAddr( address addrLostIWillApprove, address _new_main, address _new_candidate ) public whenNotPaused returns(int256)
    {
        address myIdx = getIndex( msg.sender );
        if( myIdx == address(0) )
        {
            return 1;
        }
        
        address lostIdx = getIndex( addrLostIWillApprove );
        if( lostIdx == address(0) )
        {
        		return 2;
        }
        
        bool bApproved = mapMultiSignApprove[lostIdx].mapSign[myIdx];
        if( !bApproved )
        {
        	  // 我未得到授权
            return 3;
        }
        
        uint256 uiMinCount = mapMultiSignApprove[lostIdx].uiEffectiveCount;
        if( uiMinCount == 0 )
        {
        		// 不允许最小授权数为0的情况
            return 4;
        }
        address addrCandidate = _getCurrentCandidate( lostIdx ); 
        if( mapMultiSignResult[addrCandidate].uiAgreeCount < uiMinCount )
        {
            return 5;
        }
        
        
        // 问题：签名者是否必须是当前身份、或备用身份（不允许用过期的老身份）
        address addrMyActiveZid = _getActiveZid(myIdx);
        address addrMyCandidate = _getCurrentCandidate(myIdx);
        if( addrMyActiveZid != msg.sender && addrMyCandidate != msg.sender )
        {
        	return 6;
        }
        
        
        _ZidApproveClaimed( addrLostIWillApprove, _new_main, _new_candidate );
 
        
        emit evtSignerSetNewAddr( msg.sender, addrLostIWillApprove, _new_main, _new_candidate );
        return 0;
    }
}

