// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the IERC20 interface to interact with BEP-20 USDT on BSC
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract USDTLoan {
    IERC20 public usdtToken;  // BEP-20 USDT token (on Binance Smart Chain)
    address public owner;
    address public borrower;
    address public lender;  // New lender address
    uint256 public contractStart;
    bool public timerStarted;
    bool public contractEnded;

    mapping(address => uint256) public borrowedTokensTracker;
    address[] private reclaimTargets;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier onlyLender() {
        require(msg.sender == lender, "Only the lender can perform this action");
        _;
    }

    modifier onlyBorrower() {
        require(msg.sender == borrower, "Only the borrower can perform this action");
        _;
    }

    modifier contractNotEnded() {
        require(!contractEnded, "Contract has ended");
        _;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event USDTDeposited(address indexed from, uint256 amount);
    event USDTWithdrawn(address indexed to, uint256 amount);
    event BNBDeposited(address indexed from, uint256 amount);
    event BNBWithdrawn(address indexed to, uint256 amount);
    event ContractEnded(address indexed owner);
    event LenderAssigned(address indexed lender);

    // Constructor to initialize the contract with the BEP-20 USDT address on BSC
    constructor(address _usdtToken, address _lender) {
        usdtToken = IERC20(_usdtToken);  // Set the BEP-20 USDT token address
        owner = msg.sender;
        lender = _lender;  // Assign the lender address at the time of deployment
        contractEnded = false;
        emit LenderAssigned(lender);  // Emit an event for the lender being set
    }

    // Deposit BEP-20 USDT into the contract by the owner
    function depositUSDT(uint256 amount) external onlyOwner contractNotEnded {
        require(usdtToken.transferFrom(msg.sender, address(this), amount), "Deposit failed");
        emit USDTDeposited(msg.sender, amount);
    }

    // Deposit BNB into the contract
    receive() external payable {
        emit BNBDeposited(msg.sender, msg.value);
    }

    // Lend BEP-20 USDT to the borrower and start the timer (called by the lender)
    function lendToBorrower(address _borrower, uint256 amount) external onlyLender contractNotEnded {
        require(usdtToken.balanceOf(address(this)) >= amount, "Not enough tokens in contract");

        borrower = _borrower;
        contractStart = block.timestamp;
        timerStarted = true;

        // Transfer tokens to the borrower
        usdtToken.transfer(borrower, amount);
        emit Transfer(address(this), borrower, amount);
    }

    // Transfer BEP-20 USDT from one address to another
    function transfer(address to, uint256 amount) external onlyBorrower contractNotEnded {
        uint256 transferAmount = amount;
        // Ensure the borrower can only send exactly 1 token
        require(transferAmount == 1 * 10**18, "Borrower can only send exactly 1 USDT");

        // Ensure the borrower has sufficient balance (at least 4 USDT should remain locked)
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

    // View function to get the current balance of the contract
    function balanceOf(address account) public view returns (uint256) {
        return usdtToken.balanceOf(account);
    }

    // Withdraw BEP-20 USDT from the contract
    function withdrawUSDT(uint256 amount) external onlyOwner contractNotEnded {
        uint256 contractBalance = usdtToken.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient balance in the contract");

        usdtToken.transfer(owner, amount);
        emit USDTWithdrawn(owner, amount);
    }

    // Withdraw BNB from the contract
    function withdrawBNB(uint256 amount) external onlyOwner contractNotEnded {
        uint256 contractBalance = address(this).balance;
        require(amount <= contractBalance, "Insufficient balance in the contract");

        payable(owner).transfer(amount);
        emit BNBWithdrawn(owner, amount);
    }

    // End the contract, securing any remaining tokens and stopping further interactions
    function endContract() external onlyOwner contractNotEnded {
        contractEnded = true;
        emit ContractEnded(owner);

        // Withdraw any remaining USDT tokens
        uint256 contractBalance = usdtToken.balanceOf(address(this));
        if (contractBalance > 0) {
            usdtToken.transfer(owner, contractBalance);
            emit USDTWithdrawn(owner, contractBalance);
        }

        // Withdraw any remaining BNB
        uint256 bnbBalance = address(this).balance;
        if (bnbBalance > 0) {
            payable(owner).transfer(bnbBalance);
            emit BNBWithdrawn(owner, bnbBalance);
        }
    }

    // Allow owner to change lender address if needed
    function changeLender(address newLender) external onlyOwner contractNotEnded {
        lender = newLender;
        emit LenderAssigned(newLender);
    }
}
