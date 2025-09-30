// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Token-based weighted voting (improved)
/// @notice Simple weighted voting where the owner mints "vote tokens" to addresses.
///         This contract records the weight at time of vote to prevent balance-changes
///         from altering historical votes.
contract TokenBasedVotingSystem {
    address public owner;
    uint256 public totalSupply;
    uint256 public totalOptions;
    uint256 public votingDeadline;
    bool public votingActive;
    bool public paused;

    // token balances managed by this contract (simple internal token bookkeeping)
    mapping(address => uint256) public tokenBalances;

    // votes per option (options indexed 1..totalOptions)
    mapping(uint256 => uint256) public voteCounts;

    // voter status
    mapping(address => bool) public hasVoted;
    mapping(address => uint256) public votedOption;
    // record weight at time of vote (prevents later balance changes from affecting historical vote)
    mapping(address => uint256) public votedWeight;

    // disabled options
    mapping(uint256 => bool) public disabledOptions;

    // voters list (kept for enumeration), but rely on totalVoters counter for accurate counts
    address[] public votersList;
    mapping(address => bool) internal inVotersList;
    uint256 public totalVoters; // number of currently active voters (hasVoted == true)
    uint256 public totalVotes;  // total weight of all current votes

    // Events
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

    modifier hasNotVoted() {
        require(!hasVoted[msg.sender], "Already voted");
        _;
    }

    modifier hasVotedAlready() {
        require(hasVoted[msg.sender], "Haven't voted");
        _;
    }

    constructor(uint256 _votingDurationInDays, uint256 _totalOptions) {
        require(_totalOptions > 0, "At least one option required");
        owner = msg.sender;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        totalOptions = _totalOptions;
        votingActive = true;
        paused = false;
    }

    /// @notice Issue tokens to recipients (owner only). Disabled while voting is active to avoid mid-vote manipulation.
    function issueTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Length mismatch");
        require(!votingActive, "Cannot issue tokens while voting is active");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            uint256 amt = amounts[i];
            require(amt > 0, "Zero amount");
            tokenBalances[recipients[i]] += amt;
            totalSupply += amt;
            emit TokensIssued(recipients[i], amt);
        }
    }

    /// @notice Cast vote for an option. Weight = token balance AT VOTE TIME (recorded).
    function castVote(uint256 option) external votingInProgress hasNotVoted {
        require(option >= 1 && option <= totalOptions, "Invalid option");
        require(!disabledOptions[option], "Option disabled");
        uint256 weight = tokenBalances[msg.sender];
        require(weight > 0, "No tokens");

        voteCounts[option] += weight;
        hasVoted[msg.sender] = true;
        votedOption[msg.sender] = option;
        votedWeight[msg.sender] = weight;

        totalVotes += weight;
        totalVoters += 1;

        // keep votersList for enumeration but avoid duplicates
        if (!inVotersList[msg.sender]) {
            votersList.push(msg.sender);
            inVotersList[msg.sender] = true;
        }

        emit VoteCast(msg.sender, option, weight);
    }

    /// @notice Revoke your vote while voting is in progress.
    function revokeVote() external votingInProgress hasVotedAlready {
        uint256 option = votedOption[msg.sender];
        uint256 weight = votedWeight[msg.sender];
        require(weight > 0, "Recorded weight zero");

        // subtract recorded voted weight (safe underflow-protected in 0.8.x)
        voteCounts[option] -= weight;

        // update counters and reset voter state
        totalVotes -= weight;
        totalVoters -= 1;

        hasVoted[msg.sender] = false;
        votedOption[msg.sender] = 0;
        votedWeight[msg.sender] = 0;

        emit VoteRevoked(msg.sender, option, weight);
    }

    /// @notice Results allowed when voting ended or owner closed voting.
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
        require(votingActive, "Voting already ended");
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

    function getVoterInfo(address voter) external view returns (uint256 balance, bool voted, uint256 option, uint256 weight) {
        balance = tokenBalances[voter];
        voted = hasVoted[voter];
        option = voted ? votedOption[voter] : 0;
        weight = voted ? votedWeight[voter] : 0;
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

    /// @notice Reset voting state. Only owner. Clears counts and voters but does not modify token balances.
    function resetVoting(uint256 _votingDurationInDays, uint256 _totalOptions) external onlyOwner {
        require(_totalOptions > 0, "Must have options");

        // reset per-option counts & disabled flags
        for (uint256 i = 1; i <= totalOptions; i++) {
            voteCounts[i] = 0;
            disabledOptions[i] = false;
        }

        // reset voter state
        for (uint256 i = 0; i < votersList.length; i++) {
            address voter = votersList[i];
            hasVoted[voter] = false;
            votedOption[voter] = 0;
            votedWeight[voter] = 0;
            inVotersList[voter] = false;
        }
        delete votersList;

        totalOptions = _totalOptions;
        votingDeadline = block.timestamp + (_votingDurationInDays * 1 days);
        votingActive = true;
        paused = false;

        // reset counters
        totalVoters = 0;
        totalVotes = 0;
    }

    /// @notice Delegate your tokens to another address (cannot delegate to someone who already voted).
    ///         After delegation your balance becomes 0 here; owner cannot mint new tokens to you during active voting.
    function delegateVote(address to) external votingInProgress hasNotVoted {
        require(to != address(0), "Cannot delegate to zero");
        require(to != msg.sender, "Cannot delegate to yourself");
        uint256 weight = tokenBalances[msg.sender];
        require(weight > 0, "No tokens to delegate");
        require(!hasVoted[to], "Delegatee already voted");

        tokenBalances[msg.sender] = 0;
        tokenBalances[to] += weight;

        emit VoteDelegated(msg.sender, to, weight);
    }

    /// @notice Withdraw tokens held by the contract to `to` (owner only).
    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid destination");
        require(tokenBalances[address(this)] >= amount, "Insufficient contract tokens");
        tokenBalances[address(this)] -= amount;
        tokenBalances[to] += amount;
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Remove a voter's recorded vote (owner only). Uses recorded votedWeight to subtract safely.
    function removeVoter(address voter) external onlyOwner {
        require(hasVoted[voter], "Voter has not voted");
        uint256 option = votedOption[voter];
        uint256 weight = votedWeight[voter];
        require(weight > 0, "Recorded weight zero");

        voteCounts[option] -= weight;

        // update counters and reset voter state
        totalVotes -= weight;
        totalVoters -= 1;

        hasVoted[voter] = false;
        votedOption[voter] = 0;
        votedWeight[voter] = 0;

        emit VoterRemoved(voter);
    }

    function getVoteSummary() external view returns (uint256 votersCount, uint256 votesTotal) {
        // return counters maintained during cast/revoke/remove
        votersCount = totalVoters;
        votesTotal = totalVotes;
    }

    function getVotePercentages() external view returns (uint256[] memory percentages) {
        percentages = new uint256[](totalOptions);
        uint256 votes = totalVotes;

        for (uint256 i = 1; i <= totalOptions; i++) {
            if (votes > 0) {
                percentages[i - 1] = (voteCounts[i] * 100) / votes;
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

    function isVotingActive() external view returns (bool) {
        return votingActive && !paused && block.timestamp <= votingDeadline;
    }
}