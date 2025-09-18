// Contract Configuration
const CONTRACT_CONFIG = {
    // Replace with your deployed contract address
    contractAddress: '0x1234567890123456789012345678901234567890',
    // Replace with your contract ABI
    contractABI: [
        // Minimal ABI for demonstration - replace with your actual contract ABI
        "function createProposal(string memory title, string memory description, uint256 votingPeriod) external",
        "function vote(uint256 proposalId, bool support) external",
        "function delegate(address delegatee) external",
        "function getProposal(uint256 proposalId) external view returns (tuple(string title, string description, uint256 startTime, uint256 endTime, uint256 forVotes, uint256 againstVotes, bool executed, address proposer))",
        "function getProposalCount() external view returns (uint256)",
        "function balanceOf(address account) external view returns (uint256)",
        "function delegates(address account) external view returns (address)",
        "function getVotes(address account) external view returns (uint256)",
        "event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title)",
        "event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes)",
        "event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate)"
    ]
};

class VotingApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.contract = null;
        this.currentAccount = null;
        this.proposals = [];
        
        this.init();
    }

    async init() {
        this.setupEventListeners();
        this.setupTabNavigation();
        await this.checkWalletConnection();
        this.loadMockData(); // Remove this when connecting to real contract
    }

    setupEventListeners() {
        // Wallet connection
        document.getElementById('connectWallet').addEventListener('click', () => this.connectWallet());
        
        // Form submissions
        document.getElementById('createProposalForm').addEventListener('submit', (e) => this.handleCreateProposal(e));
        document.getElementById('delegateForm').addEventListener('submit', (e) => this.handleDelegate(e));
        
        // Modal controls
        document.querySelector('.close-btn').addEventListener('click', () => this.closeModal());
        document.getElementById('voteFor').addEventListener('click', () => this.handleVote(true));
        document.getElementById('voteAgainst').addEventListener('click', () => this.handleVote(false));
        
        // Filter controls
        document.getElementById('proposalFilter').addEventListener('change', (e) => this.filterProposals(e.target.value));
        
        // Close modal when clicking outside
        window.addEventListener('click', (e) => {
            const modal = document.getElementById('proposalModal');
            if (e.target === modal) {
                this.closeModal();
            }
        });
    }

    setupTabNavigation() {
        const tabBtns = document.querySelectorAll('.tab-btn');
        const tabContents = document.querySelectorAll('.tab-content');

        tabBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                const tabName = btn.getAttribute('data-tab');
                
                // Remove active class from all tabs and contents
                tabBtns.forEach(b => b.classList.remove('active'));
                tabContents.forEach(c => c.classList.remove('active'));
                
                // Add active class to clicked tab and corresponding content
                btn.classList.add('active');
                document.getElementById(tabName).classList.add('active');
                
                // Load data based on active tab
                this.handleTabChange(tabName);
            });
        });
    }

    async handleTabChange(tabName) {
        switch(tabName) {
            case 'proposals':
                await this.loadProposals();
                break;
            case 'delegate':
                await this.loadDelegationInfo();
                break;
            case 'stats':
                await this.loadStats();
                break;
        }
    }

    async connectWallet() {
        try {
            if (typeof window.ethereum === 'undefined') {
                this.showToast('Please install MetaMask to use this application', 'error');
                return;
            }

            // Request account access
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            
            // Initialize ethers provider
            this.provider = new ethers.BrowserProvider(window.ethereum);
            this.signer = await this.provider.getSigner();
            this.currentAccount = await this.signer.getAddress();
            
            // Initialize contract
            this.contract = new ethers.Contract(
                CONTRACT_CONFIG.contractAddress,
                CONTRACT_CONFIG.contractABI,
                this.signer
            );

            // Update UI
            this.updateWalletUI();
            this.showToast('Wallet connected successfully!', 'success');
            
            // Load initial data
            await this.loadProposals();
            await this.loadTokenBalance();

        } catch (error) {
            console.error('Error connecting wallet:', error);
            this.showToast('Failed to connect wallet', '
