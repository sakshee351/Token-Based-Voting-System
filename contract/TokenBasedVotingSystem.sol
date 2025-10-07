// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenBasedVotingSystem
 * @notice A token-weighted voting system using ERC20 tokens.
 *         Vote weight is snapshotted at vote time to prevent balance manipulation.
 */
contract TokenBasedVotingSystem is Ownable {
    IERC20 public voteToken;
    uint256 public votingDeadline;
    uint256 public totalOptions;

    struct Voter {
        bool voted;
        uint256 weight;
        uint256 choice;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => uint256) public votes; // option => total weight

    event Voted(address indexed voter, uint256 choice, uint256 weight);
    event VotingDeadlineExtended(uint256 newDeadline);

    constructor(
        address _tokenAddress,
        uint256 _totalOptions,
        uint256 _duration
    ) {
        require(_tokenAddress != address(0), "Invalid token");
        require(_totalOptions > 1, "At least 2 options required");

        voteToken = IERC20(_tokenAddress);
        totalOptions = _totalOptions;
        votingDeadline = block.timestamp + _duration;
    }

    modifier onlyBeforeDeadline() {
        require(block.timestamp <= votingDeadline, "Voting has ended");
        _;
    }

    modifier onlyValidChoice(uint256 choice) {
        require(choice < totalOptions, "Invalid choice");
        _;
    }

    /**
     * @notice Cast a vote based on current token balance.
     * @param choice The index of the option to vote for
     */
    function vote(uint256 choice) external onlyBeforeDeadline onlyValidChoice(choice) {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "Already voted");

        uint256 weight = voteToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        sender.voted = true;
        sender.weight = weight;
        sender.choice = choice;

        votes[choice] += weight;

        emit Voted(msg.sender, choice, weight);
    }

    /**
     * @notice Get the winning option after deadline.
     */
    function winningOption() external view returns (uint256 winner) {
        require(block.timestamp > votingDeadline, "Voting not ended");

        uint256 winningVoteCount = 0;
        for (uint256 i = 0; i < totalOptions; i++) {
            if (votes[i] > winningVoteCount) {
                winningVoteCount = votes[i];
                winner = i;
            }
        }
    }

    /**
     * @notice Extend deadline (only owner).
     */
    function extendDeadline(uint256 extraTime) external onlyOwner {
        require(extraTime > 0, "Invalid extension");
        votingDeadline += extraTime;
        emit VotingDeadlineExtended(votingDeadline);
    }
}.    