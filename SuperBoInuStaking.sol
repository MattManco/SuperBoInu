// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SuperBoInuStaking is Ownable {
    IERC20 public token;

    uint256 public rewardRate = 10; // 10% annual reward
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant LOCK_PERIOD = 1 days;
    uint256 public constant EARLY_UNSTAKE_PENALTY = 50;

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) public stakes;
    address[] public stakers;

    constructor(address tokenAddress) Ownable(msg.sender) {  // <-- Fixed: Pass owner
        token = IERC20(tokenAddress);
    }

        function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");

        // Claim rewards if already staking (auto-compounding)
        if (stakes[msg.sender].amount > 0) {
            claim(); // Rewards werden automatisch wieder gestaked
            stakes[msg.sender].amount += amount;
        } else {
            stakes[msg.sender] = Stake(amount, block.timestamp);
            stakers.push(msg.sender); // add to leaderboard
        }

        token.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].startTime = block.timestamp;
    }

    function unstake() external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "Nothing staked");

        uint256 reward = calculateReward(msg.sender);
        uint256 duration = block.timestamp - userStake.startTime;

        // Early unstake penalty
        if (duration < LOCK_PERIOD) {
            reward = (reward * (100 - EARLY_UNSTAKE_PENALTY)) / 100;
        }

        uint256 amount = userStake.amount;
        userStake.amount = 0;

        // Transfer staked amount + rewards
        token.transfer(msg.sender, amount + reward);
    }

    function claim() public {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No active stake");

        uint256 reward = calculateReward(msg.sender);

        // Auto-compounding: reward wird direkt wiedergestaked
        userStake.amount += reward;
        userStake.startTime = block.timestamp;
    }

    function calculateReward(address user) public view returns (uint256) {
        Stake storage userStake = stakes[user];
        if (userStake.amount == 0) return 0;

        uint256 duration = block.timestamp - userStake.startTime;
        uint256 reward = (userStake.amount * rewardRate * duration) / (100 * SECONDS_PER_YEAR);
        return reward;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }

    // Leaderboard: returns top N stakers
    function getTopStakers(uint256 topN) external view returns (address[] memory, uint256[] memory) {
        uint256 count = stakers.length;
        if (topN > count) topN = count;

        // Create a temporary copy of stakers in memory
        address[] memory tempStakers = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            tempStakers[i] = stakers[i];
        }

        // Sort the temporary array (selection sort)
        for (uint256 i = 0; i < topN; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < count; j++) {
                if (stakes[tempStakers[j]].amount > stakes[tempStakers[maxIndex]].amount) {
                    maxIndex = j;
                }
            }
            // Swap in memory (does not modify storage)
            (tempStakers[i], tempStakers[maxIndex]) = (tempStakers[maxIndex], tempStakers[i]);
        }

        // Prepare results
        address[] memory topAddresses = new address[](topN);
        uint256[] memory topAmounts = new uint256[](topN);
        for (uint256 i = 0; i < topN; i++) {
            topAddresses[i] = tempStakers[i];
            topAmounts[i] = stakes[tempStakers[i]].amount;
        }

        return (topAddresses, topAmounts);
    }
}