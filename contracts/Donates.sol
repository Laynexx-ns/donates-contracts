// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

    import "./Types.sol";

contract Donates {
    address payable public owner; 

    //constants 
    uint public K;
    uint constant public SCALE = 1000;
    uint constant public MINIMAL_DONATE = 3888342360768 wei; //~10 cents

    //other variables
    mapping(address => UserBank) public users;
    uint private ownerBalance;

    //events
    event UserCreated(string indexed uuid, string name);
    event PaymentCredited(string indexed streamerUUid, Payment payment, PaymentType indexed paymentType);
    // event CommissionChanged(uint currentComission);


    constructor(uint k) {
        require(k != 0 && k < 10, "K can't be equal to 0 or more than 10");
        owner = payable(msg.sender);
        ownerBalance = 0;
        K = k*10;
    }


    //external functions

    //user functions
    function RegisterUser(string memory name, string memory uuid, string[] memory topics) external {
        require(bytes(name).length > 0, "name can't be empty");
        Wish[] memory wishes;
        Payment[] memory payments;
        
        UserBank memory user = UserBank({
            user: User({
                name: name,
                uuid: uuid,
                topics: topics,
                wishes: wishes,
                payments: payments
            }),
            currentBalance: 0
        });
        users[msg.sender] = user;
        emit UserCreated(uuid, user.user.name);
    }


    function Donate(string memory uuid, PaymentUserData memory pud, PaymentInfo memory pi) external payable {
        require(bytes(uuid).length > 0, "uuid can't be null");
        require(msg.value >= MINIMAL_DONATE, "donate must be more than 10 cent");

        Payment memory payment = Payment({
            uuid: uuid,
            paymentUserData: pud,
            paymentInfo: PaymentInfo({
                date: block.timestamp,
                toUUID: pi.toUUID,
                wishId: pi.wishId,
                toAddress: pi.toAddress,
                paymentType: PaymentType.Donate
            }),
            amount: msg.value
        });

        payAndTakeCommission(payable(payment.paymentInfo.toAddress), msg.value);
        emit PaymentCredited(payment.paymentInfo.toUUID, payment, PaymentType.Donate);  
    }

    function Withdraw(string memory uuid, uint amount) external {
         
        require(users[msg.sender].currentBalance >= amount);
        users[msg.sender].currentBalance -= amount;

        (bool send, ) = payable(msg.sender).call{value: amount}("");
        assert(send);

        Payment memory payment = Payment({
            uuid: uuid,
            paymentInfo: PaymentInfo({
                date: block.timestamp,
                toUUID: users[msg.sender].user.uuid,
                wishId: 0,
                toAddress: msg.sender,
                paymentType: PaymentType.Withdraw
            }),
            paymentUserData: PaymentUserData({
                userName: users[msg.sender].user.name,
                messageText: ""
            }),
            amount: amount
            
        });

        emit PaymentCredited(users[msg.sender].user.uuid, payment, payment.paymentInfo.paymentType);
    }

    function AddWish(Wish memory wish) external {
        require(wish.cost > 0, "cost must be more than zero");
        users[msg.sender].user.wishes.push(wish);
    }

    function RemoveWish(address useraddr, uint wishId) public {
        Wish[] storage arr = users[useraddr].user.wishes;
        for (uint i = 0; i < arr.length; i++){
            if (arr[i].id == wishId){
               arr[i] = arr[arr.length-1];
               arr.pop();
            }
        } 
    }
    

    //owner functions
    // function ChangeCommission(uint commission) external {
    //     require(msg.sender == owner, "u're not owner!");
    //     require(commission < 10, "commission can't be more than 10%");
    //     K = commission * 10;
    //     emit CommissionChanged(commission);
    // }



    //internal functions
    function payAndTakeCommission(address payable addr, uint amount) internal  {
        uint commission = (amount * K) / SCALE;
        ownerBalance+=commission;

        (bool send, ) = addr.call{value: amount-commission}("");
        assert(send);
    }    
}