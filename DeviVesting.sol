// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VestingContract is Ownable {
    using SafeMath for uint256;
    struct Vesting {
        uint256 totalAmount;
        uint256 cliff;
        uint256 duration;
        uint256 interval;
        uint256 instantTokenLeft;
        uint256 totalClaimed;
        uint256 startTime;
    }
    mapping(address => Vesting) public vesting;
    mapping(address => bool) public TotalClaimedByUser;
    uint256 public tokensVested;
    IERC20 public token;
    bool isLocked;
    

    constructor(address _add)  {
       token = IERC20(_add);
    }

    /// Reentrancy Gaurd modifier
    
    modifier nonReentrant (){
       isLocked = true;
       _;
       isLocked = false;
    }

    //Add Vesting
    function addVesting(address _user, uint256 _amount, uint256 _cliff, uint256 duration, uint256 interval, uint256 startTime, uint256 instantRate) external onlyOwner {
        require(startTime >= block.timestamp, "Start Time should be greater or equal to current time.");
        require(duration > interval, "Duration should be greater then interval");
        require(instantRate >= 0 && instantRate <= 1000, "InstantRate should be between 0 to 1000");
        uint256 getInstantTokens = 0;
        uint256 getVestingTokens = 0;
        tokensVested += _amount;
        if(instantRate == 1000){
            vesting[_user] = Vesting(0, startTime + _cliff, duration, interval, _amount, 0, startTime);
        }
        else{
            if(instantRate > 0){ 
                getInstantTokens = instantRate.mul(_amount).div(1000);
            }
            getVestingTokens = _amount - getInstantTokens;
            vesting[_user] = Vesting(getVestingTokens, startTime + _cliff, duration, interval, getInstantTokens, 0, startTime);
        }
    }

    //Claim vested token
    function claimAmount (address _recipient ) public nonReentrant {
        Vesting memory user = vesting[_recipient];
        require (!TotalClaimedByUser[_recipient], "amount already claimed");
        if(user.instantTokenLeft != 0){
            require (block.timestamp > user.startTime, "Not Started Yet");
            require (user.instantTokenLeft > 0, "No instant tokens left");
            uint256 tokens = user.instantTokenLeft;
            user.instantTokenLeft = 0;
            vesting[_recipient] = user;
            tokensVested -= tokens;
            token.transfer(_recipient, tokens);
        }
        else {
            require (block.timestamp > user.cliff, "Not Started yet" );
            uint256 endTime = block.timestamp;
            if(block.timestamp > user.cliff + user.duration){
                endTime = user.cliff + user.duration;
            }
            uint256 numberOfPeriods = (endTime.sub(user.cliff)).div(user.interval);
            uint256 totalNumberOfPeriods = user.duration.div(user.interval);
            uint256 unlockedAmount = 0;
            if(totalNumberOfPeriods == numberOfPeriods){
                unlockedAmount = user.totalAmount - user.totalClaimed;
                TotalClaimedByUser[_recipient] = true;
            } else {
                uint256 lockedAmountPerPeriod = (user.totalAmount.mul(user.interval)).div(user.duration);
                uint256 tokenReleased = lockedAmountPerPeriod.mul(numberOfPeriods);
                unlockedAmount = tokenReleased - user.totalClaimed;
            }
            user.totalClaimed += unlockedAmount;
            vesting[_recipient] = user;
            tokensVested -= unlockedAmount;
            token.transfer(_recipient, unlockedAmount);
        }
    }

    //Get Left Over tokens back

    function removeExtraTokensFromContract(address _wallet) external onlyOwner {
        token.transfer(_wallet, token.balanceOf(address(this)) - tokensVested);
    }
    
}
