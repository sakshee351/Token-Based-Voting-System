// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TokenBasedVotingSystem {
    address public owner;
[e;
    bool public
    
 event TokensIssued(address indexed recipient, uint256 amount);
    event VoteCast(address indexed voter, uint256 option, uint256 weight);
    event VoteRevoked(address indexed voter, uint256 option, uint256 weight);
    event VotingEnded();
    event VotingPaused();
    event VotingUnpaused();
 event TokensIssued(address indexed recipient, uint256 amount);
    event VoteCast(address indexed voter, uint256 option, uint256 weight);
    event VoteRevoked(address indexed voter, uint256 option, uint256 
    event VotingEnded();
    event VotingPaused();
    event VotingUnpaused();

    event TokensIssued(address indexed recipient, uint256 amount);
    event VoteCast(address indexed voter, uint256 option, uint256 weight);
    event VoteRevoked(address indexed voter, uint256 option, uint256 weight);
    event VotingEnded();
    event VotingPaused();
    event VotingUnpaused();
    event VotingExtended(uint256 newDeadline);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event VoterRemoved(address indexed voter);
    event OptionDisabled(uint256 indexed option);
    event VoteDelegated(address indexed from, address indexed to, uint256 weight);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier votingInProgress() {
        require(votingActive && !paused && block.timestamp <= votingDeadline, "Voting not active");
        _;
    }


    modifier hasVotedAlready() {
        require(hasVoted[msg.sender], "Haven't voted");
        _;
    }

    constructor(uint256 _votingDurationInDays, uint256 _totalOptions) {
        require(_totalOptions > 0, "At least one option");
        owner = msg.sender;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        totalOptions = _totalOptions;
        votingActive = true;
        paused = false;
    }

    function issueTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid address");
            require(amounts[i] > 0, "Zero tokens");

            tokenBalances[recipients[i]] += amounts[i];
            totalSupply += amounts[i];
            emit TokensIssued(recipients[i], amounts[i]);
        }
    }

    function castVote(uint256 option) external votingInProgress hasNotVoted {
        require(option >= 1 && option <= totalOptions, "Invalid option");
        require(!disabledOptions[option], "Option disabled");
        uint256 weight = tokenBalances[msg.sender];
        require(weight > 0, "No tokens");

        voteCounts[option] += weight;
        hasVoted[msg.sender] = true;
        votedOption[msg.sender] = option;
        votersList.push(msg.sender);
        emit VoteCast(msg.sender, option, weight);
    }

    function revokeVote() external votingInProgress hasVotedAlready {
        uint256 option = votedOption[msg.sender];
        uint256 weight = tokenBalances[msg.sender];

        voteCounts[option] -= weight;
        hasVoted[msg.sender] = false;
        votedOption[msg.sender] = 0;
        emit VoteRevoked(msg.sender, option, weight);
    }

        uint256 oldOption = votedOption[msg.sender];
        uint256 weight = tokenBalances[msg.sender];

       
    }

    function getResults() external view returns (uint256 winningOption, uint256 winningVotes, uint256[] memory allVotes) {
        require(block.timestamp > votingDeadline || !votingActive, "Voting ongoing");

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

    function endVoting() external onlyOwner {
        require(votingActive, "Already ended");
        votingActive = false;
        emit VotingEnded();
    }

    function pauseVoting() external onlyOwner {
        paused = true;
        emit VotingPaused();
    }

    function unpauseVoting() external onlyOwner {
        paused = false;
        emit VotingUnpaused();
    }

    function extendVoting(uint256 extraDays) external onlyOwner {
        require(votingActive, "Voting ended");
        votingDeadline += (extraDays * 1 days);
        emit VotingExtended(votingDeadline);
    }

    function getVoterInfo(address voter) external view returns (uint256 balance, bool voted, uint256 option) {
        balance = tokenBalances[voter];
        voted = hasVoted[voter];
        option = voted ? votedOption[voter] : 0;
    }

    function getContractInfo() external view returns (uint256 deadline, uint256 options, bool active, uint256 supply, bool isPaused) {
        return (votingDeadline, totalOptions, votingActive, totalSupply, paused);
    }

    function getAllVoters() external view returns (address[] memory) {
        return votersList;
    }

    function getVoteWeight(address voter) external view returns (uint256) {
        return tokenBalances[voter];
    }

    function resetVoting(uint256 _votingDurationInDays, uint256 _totalOptions) external onlyOwner {
        require(_totalOptions > 0, "Must have options");

        for (uint256 i = 1; i <= totalOptions; i++) {
            voteCounts[i] = 0;
            disabledOptions[i] = false;
        }

        for (uint256 i = 0; i < votersList.length; i++) {
            address voter = votersList[i];
            hasVoted[voter] = false;
            votedOption[voter] = 0;
        }
        delete votersList;

        totalOptions = _totalOptions;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        votingActive = true;
        paused = false;
    }

    // 🔥 New Extra Functions

    // Delegate your voting power to another voter
    function delegateVote(address to) external votingInProgress hasNotVoted {
        require(to != address(0), "Cannot delegate to zero address");
        require(to != msg.sender, "Cannot delegate to yourself");
        uint256 weight = tokenBalances[msg.sender];
        require(weight > 0, "No tokens to delegate");
        require(!hasVoted[to], "Delegatee already voted");

        tokenBalances[msg.sender] = 0; // remove tokens from delegator
        tokenBalances[to] += weight;   // add tokens to delegatee

        emit VoteDelegated(msg.sender, to, weight);
    }

    // Withdraw tokens held by contract back to owner
    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(tokenBalances[address(this)] >= amount, "Insufficient tokens");
        tokenBalances[address(this)] -= amount;
        tokenBalances[to] += amount;
    }

    // Change ownership
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    // Remove a voter (undo their vote)
    function removeVoter(address voter) external onlyOwner {
        require(hasVoted[voter], "Not voted");
        uint256 option = votedOption[voter];
        uint256 weight = tokenBalances[voter];
        voteCounts[option] -= weight;
        hasVoted[voter] = false;
        votedOption[voter] = 0;
        emit VoterRemoved(voter);
    }

    function getVoteSummary() external view returns (uint256 totalVoters, uint256 totalVotes) {
        totalVoters = votersList.length;
        totalVotes = 0;
        for (uint256 i = 1; i <= totalOptions; i++) {
            totalVotes += voteCounts[i];
        }
    }

    function getVotePercentages() external view returns (uint256[] memory percentages) {
        percentages = new uint256[](totalOptions);
        uint256 totalVotes = 0;

        for (uint256 i = 1; i <= totalOptions; i++) {
            totalVotes += voteCounts[i];
        }

        for (uint256 i = 1; i <= totalOptions; i++) {
            if (totalVotes > 0) {
                percentages[i - 1] = (voteCounts[i] * 100) / totalVotes;
            } else {
                percentages[i - 1] = 0;
            }
        }
    }

    function disableOption(uint256 option) external onlyOwner {
        require(option >= 1 && option <= totalOptions, "Invalid option");
        disabledOptions[option] = true;
        emit OptionDisabled(option);
    }

    function isOptionDisabled(uint256 option) external view returns (bool) {
        return disabledOptions[option];
    }

    // Check if voting is currently paused or active
    function isVotingActive() external view returns (bool) {
        return votingActive && !paused && block.timestamp <= votingDeadline;
    }
}
