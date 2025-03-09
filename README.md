1. โค้ดที่ป้องกันการ lock เงินไว้ใน contract
ในโค้ดนี้มีฟังก์ชัน endGameIfTimeoutExceeded และ unstuckAndRefund ซึ่งจัดการกับกรณีที่เกมไม่สามารถดำเนินการได้เนื่องจากเวลาที่กำหนดหมดลง (timeout) หรือผู้เล่นไม่ครบทั้งสองคน ทำให้เงินที่ฝากไว้ใน contract ถูกคืนให้กับผู้เล่น โดยฟังก์ชันเหล่านี้ช่วยป้องกันไม่ให้เงินถูกล็อคใน contract เกินไป

ฟังก์ชัน endGameIfTimeoutExceeded:
ฟังก์ชันนี้จะถูกเรียกใช้เมื่อผู้เล่นสองคนเข้าร่วมแล้ว แต่ไม่ได้ทำการเปิดเผยการเลือก (reveal) ภายในระยะเวลาที่กำหนด (60 วินาที หรือ 1 นาที)
เมื่อเวลาผ่านไปเกิน 60 วินาที จะทำการคืนเงินให้กับผู้เล่นที่เรียกฟังก์ชันนี้ (ซึ่งต้องไม่ทำการ reveal choice แล้ว)
หากไม่ครบเงื่อนไข จะไม่คืนเงินและสามารถใช้ได้แค่ในกรณีที่เวลาหมด
solidity
Copy
Edit
// Function to withdraw reward if opponent fails to reveal
    function withdrawIfOpponentFailsToReveal() public onlyAllowedPlayers {
        require(numPlayer == 2, "Game not started");
        require(timeunit.elapsedSeconds() > 60, "Time not expired yet");

        // Check if one of the players hasn't revealed their choice
        require(numInput < 2, "Both players have already revealed");

        address payable withdrawer;
        if (numInput == 1) {
            withdrawer = payable(players[0]);
            if (player_not_played[players[0]]) {
                withdrawer = payable(players[1]);
            }
        } else {
            withdrawer = payable(players[0]);
        }
ฟังก์ชัน unstuckAndRefund:
ฟังก์ชันนี้จะถูกเรียกใช้เมื่อมีเพียงผู้เล่นคนเดียวที่เข้าร่วมเกม แต่ไม่ได้ทำการเปิดเผยการเลือกภายใน 300 วินาที (5 นาที)
เมื่อเวลาผ่านไปเกิน 300 วินาที จะคืนเงินให้กับผู้เล่นที่เข้าร่วม
หากไม่ครบเงื่อนไขจะไม่คืนเงิน
solidity
Copy
Edit
function unstuckAndRefund() public payable {
    require(numPlayer == 1);
    require(timeunit.elapsedSeconds() > 300, "Time not expired yet");
    if (timeunit.elapsedSeconds() > 300) {
        payable(players[0]).transfer(reward);
    }
    numPlayer = 0;
    reward = 0;
    numInput = 0;
    delete players;
}
2. โค้ดที่ทำการซ่อน choice และ commit
การซ่อน choice และ commit จะเกิดขึ้นในฟังก์ชัน commitMove และ revealMove ที่ใช้ระบบการ commit-reveal ซึ่งช่วยให้ผู้เล่นสามารถซ่อนการเลือก (choice) และทำการเปิดเผย (reveal) การเลือกภายหลังในช่วงเวลาที่เหมาะสม

ฟังก์ชัน commitMove:
ฟังก์ชันนี้จะรับข้อมูลของ commitment (hash) ที่ถูกสร้างขึ้นจากการเลือก (choice) และ salt ที่ผู้เล่นตั้งไว้
Commitment คือค่าที่คำนวณจากการรวม choice และ salt ในการเข้ารหัสเป็น hash ซึ่งช่วยป้องกันไม่ให้ผู้เล่นเปลี่ยนการเลือกภายหลัง
ผู้เล่นจะทำการ commit โดยการส่ง _commitment และ _salt ไปยัง contract ผ่านฟังก์ชันนี้
solidity
Copy
Edit
function commitMove(bytes32 _commitment, uint256 _choice, string memory _salt) external onlyPlayers {
    commitReveal.commitMove(msg.sender, _commitment, _choice, _salt);
}
ฟังก์ชัน revealMove:
หลังจาก commit ไปแล้ว ผู้เล่นจะต้องทำการเปิดเผย (reveal) การเลือกของตนเองโดยส่ง choice และ salt กลับไปยัง contract
ฟังก์ชันนี้จะตรวจสอบว่าเลือกในช่วงที่ยังไม่เปิดเผย (player_not_played) และตรวจสอบว่า choice เป็นค่าที่ถูกต้อง (0-4)
หากการเปิดเผยสำเร็จ จะนำ choice มาตัดสินผลการเล่น
solidity
Copy
Edit
function revealMove(uint256 choice, string memory salt) external onlyPlayers {
    require(player_not_played[msg.sender], "Already revealed");
    require(choice >= 0 && choice <= 4, "Invalid choice");
    require(commitReveal.reveal(msg.sender, choice, salt), "Invalid reveal");
    player_choice[msg.sender] = choice;
    player_not_played[msg.sender] = false;
    numInput++;

    if (numInput == 2) {
        _checkWinnerAndPay();
    }
}
3. โค้ดที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคน
ในกรณีที่ผู้เล่นไม่ครบทั้งสองคนภายในระยะเวลาที่กำหนด ฟังก์ชัน unstuckAndRefund จะทำการคืนเงินให้กับผู้เล่นคนเดียวที่เข้าร่วมในเกม

หากมีผู้เล่นแค่คนเดียวในเกม และเวลาผ่านไปเกิน 300 วินาที (5 นาที) จะคืนเงินให้กับผู้เล่นที่เหลือ
ฟังก์ชันนี้จะทำการคืนเงินหากเงื่อนไขต่าง ๆ ถูกต้อง
solidity
Copy
Edit
function unstuckAndRefund() public payable {
    require(numPlayer == 1);
    require(timeunit.elapsedSeconds() > 300, "Time not expired yet");
    if (timeunit.elapsedSeconds() > 300) {
        payable(players[0]).transfer(reward);
    }
    numPlayer = 0;
    reward = 0;
    numInput = 0;
    delete players;
}
4. โค้ดที่ทำการ reveal และนำ choice มาตัดสินผู้ชนะ
ฟังก์ชัน revealMove จะเปิดเผยการเลือกของผู้เล่น และนำ choice ที่เปิดเผยไปตัดสินผู้ชนะในเกม

ผู้เล่นที่เรียกฟังก์ชัน revealMove จะทำการเปิดเผย choice ของตนเอง
หลังจากการเปิดเผยครบ 2 คนแล้ว จะมีการตรวจสอบผลการเลือก (เช่น rock, paper, scissors, lizard, Spock) และตัดสินว่าใครเป็นผู้ชนะ
ผู้ชนะจะได้รับรางวัลที่สะสมไว้ใน contract
ฟังก์ชัน _checkWinnerAndPay:
ฟังก์ชันนี้จะทำการตัดสินผลการเลือกของผู้เล่นทั้งสองคน
โดยใช้รูปแบบการตัดสินผลของเกม "Rock, Paper, Scissors, Lizard, Spock"
ถ้าผู้เล่นคนใดชนะ จะโอนรางวัลทั้งหมดให้แก่ผู้ชนะ
หากเสมอกัน รางวัลจะถูกแบ่งให้ทั้งสองคน
solidity
Copy
Edit
function _checkWinnerAndPay() private {
    uint256 p0Choice = player_choice[players[0]];
    uint256 p1Choice = player_choice[players[1]];
    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);

    if ((p0Choice + 1) % 5 == p1Choice || (p0Choice + 3) % 5 == p1Choice) {
        account1.transfer(reward);
    } else if ((p1Choice + 1) % 5 == p0Choice || (p1Choice + 3) % 5 == p0Choice) {
        account0.transfer(reward);
    } else {
        account0.transfer(reward / 2);
        account1.transfer(reward / 2);
    }
    resetGame();
}
