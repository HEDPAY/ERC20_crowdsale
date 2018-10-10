pragma solidity ^0.4.24;

import "./HedpayToken.sol";

/**
 * @title HedpayCrowdsale contract
 */
contract HedpayCrowdsale is Contactable {
  using SafeMath for uint;
  using SafeERC20 for HedpayToken;

  HedpayToken public token;

  uint8 public constant firstPhaseBonus = 30;
  uint8[3] public secondPhaseBonus = [10, 15, 20];
  uint8 public constant thirdPhaseBonus = 5;
  uint public constant firstStageStartTime = 1539118254; //09.10.2018 20:50:54 GMT
  uint public constant firstStageEndTime = 1540943999; //30.11.2018 23:59:59 GMT
  uint public constant secondStageStartTime = 1540944000; //31.10.2018 00:00:00 GMT
  uint public constant secondStageEndTime = 1543622399; //30.11.2018 23:59:59 GMT
  uint public constant thirdStageStartTime = 1543622400;//1.12.2018 00:00:00 GMT
  uint public constant thirdStageEndTime = 1545523199;//22.12.2018 23:59:59 GMT
  uint public constant cap = 200000 ether;
  uint public constant goal = 25000 ether;
  uint public constant rate = 100;
  uint public constant minimumWeiAmount = 100 finney;
  uint public constant thirdStageMinWeiAmount = 10 ether;
  uint public constant salePercent = 14;
  uint public constant bonusPercent = 1;
  uint public constant teamPercent = 2;
  uint public constant preSalePercent = 3;
  uint public constant limitBuyAmount= 100 ether;

  uint public creationTime;
  uint public weiRaised;
  uint public buyersCount;
  uint public saleAmount;
  uint public bonusAmount;
  uint public teamAmount;
  uint public preSaleAmount;


  address public teamAddress = 0x7d4E738477B6e8BaF03c4CB4944446dA690f76B5;

  mapping (address => uint) internal bonuses;

 /**
  * @dev Event for token purchase logging
  * @param purchaser who paid for the tokens
  * @param beneficiary who got the tokens
  * @param value weis paid for purchase
  * @param amount amount of tokens purchased
  */
  event TokenPurchase(
    address indexed purchaser,
    address indexed beneficiary,
    uint value,
    uint amount
  );
  event Refund(address who, uint value);
  event Finalized();

  /**
   * @dev Constructor that sets initial contract parameters
   */
  constructor(HedpayToken _token) public {
    require(address(_token) != address(0));
    token = _token;
    creationTime = block.timestamp;
    saleAmount = uint(token.totalSupply()).div(100).mul(salePercent);
    bonusAmount = uint(token.totalSupply()).div(100).mul(bonusPercent);
    teamAmount = uint(token.totalSupply()).div(100).mul(teamPercent);
    preSaleAmount = uint(token.totalSupply()).div(100).mul(preSalePercent);
  }

  /**
   * @dev Gets an account tokens bonus
   * @param _owner address the tokens owner
   * @return uint owned tokens bonus
   */
  function bonusOf(address _owner) public view returns (uint) {
    require(_owner != address(0));
    return bonuses[_owner];
  }

  /**
   * @dev Checks whether the ICO has started
   * @return bool true if the crowdsale began
   */
  function hasStarted() public view returns (bool) {
    return block.timestamp >= firstStageStartTime;
  }

  /**
   * @dev Checks whether the ICO has ended
   * @return bool `true` if the crowdsale is over
   */
  function hasEnded() public view returns (bool) {
    return block.timestamp > thirdStageEndTime;
  }

  /**
   * @dev Checks whether the cap has reached
   * @return bool `true` if the cap has reached
   */
  function capReached() public view returns (bool) {
    return weiRaised >= cap;
  }

  /**
   * @dev Gets the current tokens amount can be purchased for the specified
   * @dev wei amount
   * @param _weiAmount uint wei amount
   * @return uint tokens amount
   */
  function getTokenAmount(uint _weiAmount) public view returns (uint) {
    return _weiAmount.mul(rate).div((18 - uint(token.decimals())) ** 10);
  }

  /**
   * @dev Gets the current tokens amount can be purchased for the specified
   * @dev wei amount (including bonuses)
   * @param _weiAmount uint wei amount
   * @return uint tokens amount
   */
  function getTokenAmountBonus(uint _weiAmount)
    public view returns (uint) {
    if (block.timestamp >= firstStageStartTime && block.timestamp <= firstStageEndTime) {
      return(
        getTokenAmount(_weiAmount).
        add(
          getTokenAmount(_weiAmount).
          div(100).
          mul(uint(firstPhaseBonus))
        )
      );
    } else if (block.timestamp >= secondStageStartTime && block.timestamp <= secondStageEndTime) {
      if (_weiAmount > 0 && _weiAmount < 2500 finney) {
        return(
          getTokenAmount(_weiAmount).
          add(
            getTokenAmount(_weiAmount).
            div(100).
            mul(uint(secondPhaseBonus[0]))
          )
        );
      } else if (_weiAmount >= 2510 finney && _weiAmount < 10000 finney) {
        return(
          getTokenAmount(_weiAmount).
          add(
            getTokenAmount(_weiAmount).
            div(100).
            mul(uint(secondPhaseBonus[1]))
          )
        );
      } else if (_weiAmount >= 10000 finney) {
        return(
          getTokenAmount(_weiAmount).
          add(
            getTokenAmount(_weiAmount).
            div(100).
            mul(uint(secondPhaseBonus[2]))
          )
        );
      }
    }  else if (block.timestamp >= thirdStageStartTime && block.timestamp <= thirdStageEndTime) {
        return(
          getTokenAmount(_weiAmount).
          add(
            getTokenAmount(_weiAmount).
            div(100).
            mul(uint(thirdPhaseBonus))
          )
        );
      } else {
      return getTokenAmount(_weiAmount);
    }
  }

  /**
   *@dev fallback function
   */
  function() public payable {
    buyTokens(msg.sender);
  }

  /**
   * @dev Token purchase
   * @param _beneficiary Address performing the token purchase
   */
  function buyTokens(address _beneficiary) public payable {
	 require(_beneficiary != address(0));
     require(hasStarted() && !hasEnded());
     require(getTokenAmountBonus(msg.value) <= saleAmount); 
     require (msg.value <= limitBuyAmount);
	 require(_preValidateMinimumAmount(msg.value));
     weiRaised = weiRaised.add(msg.value);
     saleAmount = saleAmount.sub(getTokenAmountBonus(msg.value));
     token.safeTransferFrom(
      owner,
      _beneficiary,
      getTokenAmountBonus(msg.value)
    );

     emit TokenPurchase(
      msg.sender,
      _beneficiary,
      msg.value,
      getTokenAmountBonus(msg.value)
    );
  }
  
 
  /**
   * @dev Gets an account tokens balance without freezed part of the bonuses
   * @param _owner address the tokens owner
   * @return uint owned tokens amount without freezed bonuses
   */
  function balanceWithoutFreezedBonus(address _owner)
    public view returns (uint) {
    require(_owner != address(0));
    if (block.timestamp >= firstStageEndTime.add(90 days)) {
      if (bonusOf(_owner) < 10000) {
        return token.balanceOf(_owner);
      } else {
        return token.balanceOf(_owner).sub(bonuses[_owner].div(2));
      }
    } else if (block.timestamp >= secondStageEndTime.add(180 days)) {
      return token.balanceOf(_owner);
    } else {
      return token.balanceOf(_owner).sub(bonuses[_owner]);
    }
  }

  /**
   * @dev Function to set an account bonus
   * @param _owner address the tokens owner
   * @param _value uint bonus tokens amount
   */
  function setBonus(address _owner, uint _value, bool preSale)
    public onlyOwner {
    require(_owner != address(0));
    require(_value <= token.balanceOf(_owner));
    require(bonusAmount > 0);
    require(_value <= bonusAmount);
    bonuses[_owner] = _value;
    if (preSale) {
      preSaleAmount = preSaleAmount.sub(_value);
      token.transfer(_owner, _value);
    } else {
      if (_value <= bonusAmount) {
        bonusAmount = bonusAmount.sub(_value);
        token.transfer(_owner, _value);
      }
    }
  }
  /**
   * @dev Function to refill balance of the specified account
   * @param _to address the tokens recepient
   * @param _weiAmount uint amount of the tokens to be transferred
   */
  function refill(address _to, uint _weiAmount) public onlyOwner {
    require(_preValidateRefill(_to, _weiAmount));
    setBonus(
      _to,
      getTokenAmountBonus(_weiAmount).sub(
        getTokenAmount(_weiAmount)
      ),
      false
    );
    buyersCount = buyersCount.add(1);
    saleAmount = saleAmount.sub(getTokenAmount(_weiAmount));
    token.transfer(_to, getTokenAmount(_weiAmount));
  }

  /**
   * @dev Function to refill balances of the specified accounts
   * @param _to address[] the tokens recepients
   * @param _weiAmount uint[] amounts of the tokens to be transferred
   */
  function refillArray(address[] _to, uint[] _weiAmount) public onlyOwner {
    require(_to.length == _weiAmount.length);
    for (uint i = 0; i < _to.length; i++) {
      refill(_to[i], _weiAmount[i]);
    }
  }

  /**
   * @dev Function to finalize the sale and define team fund
   */
  function finalize() public onlyOwner {
    token.transfer(teamAddress, teamAmount);
    teamAmount = 0;
  }

  /**
   * @dev Internal function to prevalidate refill before execution
   * @param _to address the tokens recepient
   * @param _weiAmount uint amount of the tokens to be transferred
   * @return bool `true` if the refill can be executed
   */
  function _preValidateRefill(address _to, uint _weiAmount)
    internal view returns (bool) {
    return(
      hasStarted() && _to != address(0) && _preValidateMinimumAmount(_weiAmount)
    );
  }
  
  /**
   * @dev Internal function to check minimumWeiAmount depending on the date
   * @param _weiAmount uint amount of the tokens to be transferred
   * @return bool `true` if it's OK with value of tokens
   */
  function _preValidateMinimumAmount(uint _weiAmount)
   internal view returns (bool) {
	   if (block.timestamp >= firstStageStartTime && block.timestamp <= secondStageEndTime 
	   && _weiAmount >= minimumWeiAmount) {
          getTokenAmount(_weiAmount) <= saleAmount;
		} else if (block.timestamp >= thirdStageStartTime && !hasEnded() 
			&& _weiAmount >= thirdStageMinWeiAmount) {
          getTokenAmount(_weiAmount) <= saleAmount;
		} else
			return false;
	 }
	 
 }
   
