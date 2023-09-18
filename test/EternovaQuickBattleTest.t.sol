// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import "../contracts/EternovaQuickBattles.sol";

contract EternovaQuickBattleTest is Test {
    EternovaQuickBattles public game;

    address public user1 = vm.addr(1);    
    address public user2 = vm.addr(2);    
    address public user3 = vm.addr(3);    
    address public user4 = vm.addr(4); 

    uint constant PREDATOR_UNITS = 5;
	uint constant PROXIMUS_COBRA_UNITS = 2;
	uint constant BOUNTY_HUNTERS_UNITS = 3;
	
	uint constant STARTING_LIFE = 500;   

    function setUp() public {
        game = new EternovaQuickBattles();
    }

    function testStartBattle() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 5;
        troopsAmount[1] = 2;
        troopsAmount[2] = 3;
        vm.expectRevert("Too many troops!");
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
        
        troopsAmount[0] = 1;
        troopsAmount[1] = 2;
        troopsAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, troopsAmount);

        assertEq(game.getUserBattleCount(user1), 1);
        
        vm.prank(user1);
        EternovaQuickBattles.PublicBattleData memory data = game.getPublicBattleData(1);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,1);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,1);
        assertEq(data.proximusUnits,2);
        assertEq(data.bountyUnits,2);
        assertEq(data.cityLife,500);
        assertEq(data.winner,address(0));

        EternovaQuickBattles.BattleDataResponse[] memory response;
        response = game.getUserBattleData(user1,0,0);
        assertEq(response[0].battleId, id);
        assertEq(response[0].creator, user1);
        assertEq(response[0].opponent, user2);
        assertEq(response[0].currentRound, 1);
        assertEq(response[0].nextMove, user2);
        assertEq(response[0].winner, address(0));
        
        vm.expectRevert("Can't request too many records!");
        response = game.getUserBattleData(user1,101,0);
    }

    function testCannotStartBattleAgainsSameOpponentSimultaneusly() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 1;
        troopsAmount[1] = 2;
        troopsAmount[2] = 2;
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
        
        vm.expectRevert("Use requestBattle");
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
    }

    function testCannotStartBattleWithMoreThanAvailablePredator() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = PREDATOR_UNITS + 1;
        troopsAmount[1] = 2;
        troopsAmount[2] = 2;
        vm.expectRevert("Exceeds Predators max");
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
    }

    function testCannotStartBattleWithMoreThanAvailableProximus() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 1;
        troopsAmount[1] = PROXIMUS_COBRA_UNITS + 1;
        troopsAmount[2] = 2;
        vm.expectRevert("Exceeds Proximus Cobra max");
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
    }

    function testCannotStartBattleWithMoreThanAvailableBounty() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 1;
        troopsAmount[1] = 1;
        troopsAmount[2] = BOUNTY_HUNTERS_UNITS + 1;
        vm.expectRevert("Exceeds Bounty Hunter max");
        vm.prank(user1);
        game.startBattle(user2, troopsAmount);
    }

    function testCannotRespondBattleInexistentId() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 1;
        troopsAmount[1] = 1;
        troopsAmount[2] = 1;
        vm.startPrank(user1);
        vm.expectRevert("Battle id doesn't exist");
        game.requestBattle(2, troopsAmount);
    }

    function testCannotRespondBattleIfNotCreatorNorOpponent() public{
        uint[3] memory troopsAmount;
        troopsAmount[0] = 1;
        troopsAmount[1] = 1;
        troopsAmount[2] = 1;
        vm.startPrank(user1);
        vm.expectRevert("Battle id doesn't exist");
        game.requestBattle(2, troopsAmount);
    }

    function testRespondToBattleRound1() public{
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);
        
        uint[3] memory defenseAmount;
        defenseAmount[0] = 1;
        defenseAmount[1] = 1;
        defenseAmount[2] = 1;
        
        vm.startPrank(user2);
        game.requestBattle(id, defenseAmount);

        EternovaQuickBattles.PublicBattleData memory data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,2);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,110);
        assertEq(data.winner,address(0));

        vm.stopPrank();
        vm.prank(user1);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,2);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,500);
        assertEq(data.winner,address(0));
    }

    function testEndAllRounds() public{
        //FIRST ROUND
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);
        
        uint[3] memory defenseAmount;
        defenseAmount[0] = 1;
        defenseAmount[1] = 1;
        defenseAmount[2] = 1;
        
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        vm.prank(user2);
        EternovaQuickBattles.PublicBattleData memory data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,2);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,110);
        assertEq(data.winner,address(0));

        vm.prank(user1);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,2);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,500);
        assertEq(data.winner,address(0));

        // //SECOND ROUND
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user2);
        game.requestBattle(id, attackAmount);
        
        vm.prank(user2);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,2);
        assertEq(data.nextMove,user1);
        assertEq(data.predatorUnits,2);
        assertEq(data.proximusUnits,2);
        assertEq(data.bountyUnits,2);
        assertEq(data.cityLife,110);
        assertEq(data.winner,address(0));
        
        defenseAmount;
        defenseAmount[0] = 2;
        defenseAmount[1] = 1;
        defenseAmount[2] = 2;
        
        vm.prank(user1);
        game.requestBattle(id, defenseAmount);
        
        vm.prank(user1);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,3);
        assertEq(data.nextMove,user1);
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,220);
        assertEq(data.winner,address(0));

        //THIRD ROUND
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 3;
        vm.prank(user1);
        game.requestBattle(id, attackAmount);
        
        vm.prank(user1);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,3);
        assertEq(data.nextMove,user2);
        assertEq(data.predatorUnits,2);
        assertEq(data.proximusUnits,2);
        assertEq(data.bountyUnits,3);
        assertEq(data.cityLife,220);
        assertEq(data.winner,address(0));
        
        defenseAmount;
        defenseAmount[0] = 2;
        defenseAmount[1] = 2;
        defenseAmount[2] = 3;
        
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        
        vm.prank(user2);
        data = game.getPublicBattleData(id);
        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        assertEq(data.currentRound,0);
        assertEq(data.nextMove,address(0));
        assertEq(data.predatorUnits,0);
        assertEq(data.proximusUnits,0);
        assertEq(data.bountyUnits,0);
        assertEq(data.cityLife,0);
        assertEq(data.winner,user1);
    }

    function testCannotGetPublicBattleDataInexistentId() public{
        vm.expectRevert("Battle id doesn't exist");
        game.getPublicBattleData(1);
    }

    function testCannotGetPublicNotBeingCreatorNorOpponent() public{
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);

        vm.expectRevert("Unauthorized");
        game.getPublicBattleData(id);
    }

    function testRequestBattleRequirements() public{
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);
        
        uint[3] memory defenseAmount;
        defenseAmount[0] = 1;
        defenseAmount[1] = 1;
        defenseAmount[2] = 1;
        
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        
        //SECOND ROUND
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        
        vm.expectRevert("Battle id doesn't exist");
        vm.prank(user2);
        game.requestBattle(id + 1, attackAmount);
        
        vm.expectRevert("Can't request this battle");
        vm.prank(user3);
        game.requestBattle(id, attackAmount);
        
        vm.expectRevert("Not your turn!");
        vm.prank(user1);
        game.requestBattle(id, attackAmount);
        
        attackAmount[0] = 10;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.expectRevert("Exceeds Predators max");
        vm.prank(user2);
        game.requestBattle(id, attackAmount);
        
        attackAmount[0] = 2;
        attackAmount[1] = 10;
        attackAmount[2] = 2;
        vm.expectRevert("Exceeds Proximus Cobra max");
        vm.prank(user2);
        game.requestBattle(id, attackAmount);
        
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 10;
        vm.expectRevert("Exceeds Bounty Hunter max");
        vm.prank(user2);
        game.requestBattle(id, attackAmount);
        
        attackAmount[0] = 5;
        attackAmount[1] = 2;
        attackAmount[2] = 3;
        vm.expectRevert("Too many troops!");
        vm.prank(user2);
        game.requestBattle(id, attackAmount);
    }

    function testResponseBattleRequirements() public{
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);
        
        uint[3] memory defenseAmount;
        defenseAmount[0] = 1;
        defenseAmount[1] = 1;
        defenseAmount[2] = 1;
        
        vm.expectRevert("Battle id doesn't exist");
        vm.prank(user2);
        game.requestBattle(id + 1, defenseAmount);
        
        vm.expectRevert("Can't request this battle");
        vm.prank(user3);
        game.requestBattle(id, defenseAmount);
        
        vm.expectRevert("Not your turn!");
        vm.prank(user1);
        game.requestBattle(id, defenseAmount);
        
        defenseAmount[0] = 10;
        defenseAmount[1] = 2;
        defenseAmount[2] = 2;
        vm.expectRevert("Exceeds Predators max");
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        
        defenseAmount[0] = 2;
        defenseAmount[1] = 10;
        defenseAmount[2] = 2;
        vm.expectRevert("Exceeds Proximus Cobra max");
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        
        defenseAmount[0] = 2;
        defenseAmount[1] = 2;
        defenseAmount[2] = 10;
        vm.expectRevert("Exceeds Bounty Hunter max");
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
        
        defenseAmount[0] = 5;
        defenseAmount[1] = 2;
        defenseAmount[2] = 3;
        vm.expectRevert("Too many troops!");
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
    }

    function testHistoricInfo() public{
        //FIRST ROUND
        uint[3] memory attackAmount;
        attackAmount[0] = 1;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user1);
        uint id = game.startBattle(user2, attackAmount);
        
        uint[3] memory defenseAmount;
        defenseAmount[0] = 1;
        defenseAmount[1] = 1;
        defenseAmount[2] = 1;
        
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);
      

        // //SECOND ROUND
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 2;
        vm.prank(user2);
        game.requestBattle(id, attackAmount);        
              
        defenseAmount;
        defenseAmount[0] = 2;
        defenseAmount[1] = 1;
        defenseAmount[2] = 2;
        
        vm.prank(user1);
        game.requestBattle(id, defenseAmount);        
       
        //THIRD ROUND
        attackAmount[0] = 2;
        attackAmount[1] = 2;
        attackAmount[2] = 3;
        vm.prank(user1);
        game.requestBattle(id, attackAmount);
                     
        defenseAmount;
        defenseAmount[0] = 2;
        defenseAmount[1] = 2;
        defenseAmount[2] = 3;
        
        vm.prank(user2);
        game.requestBattle(id, defenseAmount);

        vm.prank(user2);
        EternovaQuickBattles.PublicHistoricBattleData memory data = game.getPublicHistoricBattleData(id);

        assertEq(data.creator,user1);
        assertEq(data.opponent,user2);
        
    }
}
