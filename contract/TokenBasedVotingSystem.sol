// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TokenBasedVotingSystem {
    // State variables
    address public owner;
    mapping(address => uint256) public tokenBalances;
    mapping(address => bool) public hasVoted;
    mapping(uint256 => uint256) public voteCounts;
    mapping(address => uint256) public votedOption;
    address[] public votersList;

    uint256 public totalSupply;
    uint256 public votingDeadline;
    uint256 public totalOptions;
    bool public votingActive;
    bool public paused;

    // Events
    event TokensIssued(address indexed recipient, uint256 amount);
    event VoteCast(address indexed voter, uint256 option, uint256 weight);
    event VoteRevoked(address indexed voter, uint256 option, uint256 weight);
    event VotingEnded();
    event VotingPaused();
    event VotingUnpaused();
    event VotingExtended(uint256 newDeadline);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier votingInProgress() {
        require(votingActive && !paused && block.timestamp <= votingDeadline, "Voting is not active");
        _;
    }

    modifier hasNotVoted() {
        require(!hasVoted[msg.sender], "You have already voted");
        _;
    }

    modifier hasVotedAlready() {
        require(hasVoted[msg.sender], "You have not voted yet");
        _;
    }

    // Constructor
    constructor(uint256 _votingDurationInDays, uint256 _totalOptions) {
        require(_totalOptions > 0, "There must be at least one option");
        owner = msg.sender;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        totalOptions = _totalOptions;
        votingActive = true;
        paused = false;
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
        votersList.push(msg.sender);

        emit VoteCast(msg.sender, option, voteWeight);
    }

    // Revoke vote before voting ends
    function revokeVote() external votingInProgress hasVotedAlready {
        uint256 option = votedOption[msg.sender];
        uint256 voteWeight = tokenBalances[msg.sender];

        voteCounts[option] -= voteWeight;
        hasVoted[msg.sender] = false;
        votedOption[msg.sender] = 0;

        emit VoteRevoked(msg.sender, option, voteWeight);
    }

    // Change vote before voting ends
    function changeVote(uint256 newOption) external votingInProgress hasVotedAlready {
        require(newOption >= 1 && newOption <= totalOptions, "Invalid voting option");
        uint256 oldOption = votedOption[msg.sender];
        uint256 voteWeight = tokenBalances[msg.sender];

        // Remove old vote weight
        voteCounts[oldOption] -= voteWeight;

        // Add new vote weight
        voteCounts[newOption] += voteWeight;
        votedOption[msg.sender] = newOption;

        emit VoteCast(msg.sender, newOption, voteWeight);
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

    // Pause voting
    function pauseVoting() external onlyOwner {
        paused = true;
        emit VotingPaused();
    }

    // Unpause voting
    function unpauseVoting() external onlyOwner {
        paused = false;
        emit VotingUnpaused();
    }

    // Extend voting deadline
    function extendVoting(uint256 extraDays) external onlyOwner {
        require(votingActive, "Voting has ended");
        votingDeadline += (extraDays * 1 days);
        emit VotingExtended(votingDeadline);
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
        returns (uint256 deadline, uint256 options, bool active, uint256 supply, bool isPaused)
    {
        return (votingDeadline, totalOptions, votingActive, totalSupply, paused);
    }

    // Get all voters
    function getAllVoters() external view returns (address[] memory) {
        return votersList;
    }

    // Get vote weight of a voter
    function getVoteWeight(address voter) external view returns (uint256) {
        return tokenBalances[voter];
    }

    // Reset voting (clears all votes and voters)
    function resetVoting(uint256 _votingDurationInDays, uint256 _totalOptions) external onlyOwner {
        require(_totalOptions > 0, "There must be at least one option");

        // Reset all votes
        for (uint256 i = 1; i <= totalOptions; i++) {
            voteCounts[i] = 0;
        }

        // Reset voter info
        for (uint256 i = 0; i < votersList.length; i++) {
            address voter = votersList[i];
            hasVoted[voter] = false;
            votedOption[voter] = 0;
        }
        delete votersList;

        // Reset voting parameters
        totalOptions = _totalOptions;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        votingActive = true;
        paused = false;
    }
}
