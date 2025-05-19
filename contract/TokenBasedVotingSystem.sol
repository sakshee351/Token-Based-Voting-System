// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TokenBasedVotingSystem {
    // State variables
    address public owner;
    mapping(address => uint256) public tokenBalances;
    mapping(address => bool) public hasVoted;
    mapping(uint256 => uint256) public voteCounts;
    mapping(address => uint256) public votedOption;

    uint256 public totalSupply;
    uint256 public votingDeadline;
    uint256 public totalOptions;
    bool public votingActive;

    // Events
    event TokensIssued(address indexed recipient, uint256 amount);
    event VoteCast(address indexed voter, uint256 option, uint256 weight);
    event VotingEnded();

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier votingInProgress() {
        require(votingActive && block.timestamp <= votingDeadline, "Voting is not active");
        _;
    }

    modifier hasNotVoted() {
        require(!hasVoted[msg.sender], "You have already voted");
        _;
    }

    // Constructor
    constructor(uint256 _votingDurationInDays, uint256 _totalOptions) {
        require(_totalOptions > 0, "There must be at least one option");
        owner = msg.sender;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        totalOptions = _totalOptions;
        votingActive = true;
    }

    // Issue tokens
    function issueTokens(address[] memory recipients, uint256[] memory amounts)
        external
        onlyOwner
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient address");
            require(amounts[i] > 0, "Token amount must be greater than zero");

            tokenBalances[recipients[i]] += amounts[i];
            totalSupply += amounts[i];
            emit TokensIssued(recipients[i], amounts[i]);
        }
    }

    // Cast vote
    function castVote(uint256 option)
        external
        votingInProgress
        hasNotVoted
    {
        require(option >= 1 && option <= totalOptions, "Invalid voting option");
        uint256 voteWeight = tokenBalances[msg.sender];
        require(voteWeight > 0, "No tokens to vote with");

        voteCounts[option] += voteWeight;
        hasVoted[msg.sender] = true;
        votedOption[msg.sender] = option;

        emit VoteCast(msg.sender, option, voteWeight);
    }

    // Get results
    function getResults()
        external
        view
        returns (uint256 winningOption, uint256 winningVotes, uint256[] memory allVotes)
    {
        require(block.timestamp > votingDeadline || !votingActive, "Voting still in progress");

        allVotes = new uint256[](totalOptions);
        winningVotes = 0;
        winningOption = 1;

        for (uint256 i = 1; i <= totalOptions; i++) {
            uint256 count = voteCounts[i];
            allVotes[i - 1] = count;
            if (count > winningVotes) {
                winningVotes = count;
                winningOption = i;
            }
        }
    }

    // End voting
    function endVoting() external onlyOwner {
        require(votingActive, "Voting already ended");
        votingActive = false;
        emit VotingEnded();
    }

    // Get voter info
    function getVoterInfo(address voter)
        external
        view
        returns (uint256 balance, bool voted, uint256 option)
    {
        balance = tokenBalances[voter];
        voted = hasVoted[voter];
        option = voted ? votedOption[voter] : 0;
    }

    // Get contract info
    function getContractInfo()
        external
        view
        returns (uint256 deadline, uint256 options, bool active, uint256 supply)
    {
        return (votingDeadline, totalOptions, votingActive, totalSupply);
    }
}
