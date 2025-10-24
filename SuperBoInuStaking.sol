// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SuperBoInuStaking is Ownable {
    IERC20 public token;

    uint256 public rewardRate = 10; // 10% annual reward
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) public stakes;

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = IERC20(tokenAddress);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");

        // Wenn der Benutzer bereits was gestaked hat, Rewards vorher claimen
        if (stakes[msg.sender].amount > 0) {
            claim();
        }

        token.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender] = Stake(amount, block.timestamp);
    }

    function unstake() external {
        require(stakes[msg.sender].amount > 0, "Nothing staked");

        claim(); // Rewards zuerst ausschütten

        uint256 amount = stakes[msg.sender].amount;
        stakes[msg.sender].amount = 0;

        token.transfer(msg.sender, amount);
    }

    function claim() public {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake");

        uint256 duration = block.timestamp - userStake.startTime;
        uint256 reward = (userStake.amount * rewardRate * duration) / (100 * SECONDS_PER_YEAR);

        userStake.startTime = block.timestamp; // reset timer
        token.transfer(msg.sender, reward);
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }
}