// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract LoanManager {
    // --- Roles ---
    enum Role { None, Borrower, Admin }

    address public owner;
    mapping(address => Role) public roles;

    event BorrowerRegistered(address indexed user);
    event AdminGranted(address indexed user);
    event AdminRevoked(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "only-owner");
        _;
    }

    // --- Loans ---
    enum Status { Requested, Approved, Rejected, Repaid }

    struct Loan {
        uint256 id;
        address borrower;
        uint256 amount;   // wei
        string docCid;    // IPFS CID
        Status status;
    }

    uint256 public nextId;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public byBorrower;

    event LoanRequested(uint256 id, address borrower, uint256 amount, string cid);
    event LoanApproved(uint256 id);
    event LoanRejected(uint256 id);
    event LoanRepaid(uint256 id);

    constructor() {
        owner = msg.sender;
        roles[owner] = Role.Admin; // deployer is admin by default
    }

    // ---------- Auth (Sign-up) ----------
    function registerBorrower() external {
        require(roles[msg.sender] == Role.None, "already-registered");
        roles[msg.sender] = Role.Borrower;
        emit BorrowerRegistered(msg.sender);
    }

    function grantAdmin(address user) external onlyOwner {
        roles[user] = Role.Admin;
        emit AdminGranted(user);
    }

    function revokeAdmin(address user) external onlyOwner {
        require(user != owner, "cannot-revoke-owner");
        roles[user] = Role.None;
        emit AdminRevoked(user);
    }

    function myRole(address user) external view returns (Role) {
        return roles[user];
    }

    // ---------- Loans ----------
    function requestLoan(uint256 amountWei, string calldata cid) external {
        require(roles[msg.sender] == Role.Borrower, "not-borrower");
        require(amountWei > 0, "amount=0");

        nextId++;
        loans[nextId] = Loan(nextId, msg.sender, amountWei, cid, Status.Requested);
        byBorrower[msg.sender].push(nextId);
        emit LoanRequested(nextId, msg.sender, amountWei, cid);
    }

    function approveLoan(uint256 id) external {
        require(roles[msg.sender] == Role.Admin, "not-admin");
        require(loans[id].status == Status.Requested, "bad-status");
        loans[id].status = Status.Approved;
        emit LoanApproved(id);
    }

    function rejectLoan(uint256 id) external {
        require(roles[msg.sender] == Role.Admin, "not-admin");
        require(loans[id].status == Status.Requested, "bad-status");
        loans[id].status = Status.Rejected;
        emit LoanRejected(id);
    }

    function markRepaid(uint256 id) external {
        require(loans[id].borrower == msg.sender, "only-borrower");
        require(loans[id].status == Status.Approved, "not-approved");
        loans[id].status = Status.Repaid;
        emit LoanRepaid(id);
    }

    function getMyLoans() external view returns (Loan[] memory) {
        uint256[] memory ids = byBorrower[msg.sender];
        Loan[] memory out = new Loan[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) out[i] = loans[ids[i]];
        return out;
    }
}
