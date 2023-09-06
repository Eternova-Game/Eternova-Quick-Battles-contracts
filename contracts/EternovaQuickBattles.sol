// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EternovaQuickBattles is Ownable{
	
	using Counters for Counters.Counter;

    Counters.Counter private _battleIds;

	event BattleStarted(uint indexed id, address indexed creator, address indexed opponent);
	event BattleFinished(uint id, address indexed winner, uint winnerCityLife, uint looserCityLife);

	event RoundStarted(uint indexed id, uint currentRound);	
	event RoundFinished(uint indexed id, uint currentRound);
	
	struct Troop {
		uint attack;
		uint defense;		
	}

	struct BattleData {
		address creator;
		address opponent;
		uint currentRound;
		address nextMove;
		uint predatorAttackingUnits;
		uint proximusAttackingUnits;
		uint bountyAttackingUnits;
		uint predatorDefendingUnits;
		uint proximusDefendingUnits;
		uint bountyDefendingUnits;
		uint creatorCityLife;
		uint opponentCityLife;
	}

	Troop private predator = Troop(40,100);
	Troop private proximusCobra = Troop(200,200);
	Troop private bounty_hunters = Troop(150,50);

	uint constant MAX_ROUNDS = 3;

	uint constant PREDATOR_UNITS = 5;
	uint constant PROXIMUS_COBRA_UNITS = 2;
	uint constant BOUNTY_HUNTERS_UNITS = 3;
	uint constant STARTING_LIFE = 500;

	uint constant MAX_UNITS_FIRST_ROUND = 8;
	uint constant MAX_UNITS_SECOND_ROUND = 9;
	uint constant MAX_UNITS_THIRD_ROUND = 10;

	//Round N° => Max units
	mapping(uint => uint) roundMaxUnits;
	
	uint constant FIRST_ROUND = 1;
	uint constant SECOND_ROUND = 2;
	uint constant THIRD_ROUND = 3;

	//Creator => opponent => battleId
	mapping (address => mapping (address => uint)) private currentlyFighting;

	mapping (uint => BattleData) private battle;
			
	constructor() {
		roundMaxUnits[1] = MAX_UNITS_FIRST_ROUND;		
		roundMaxUnits[2] = MAX_UNITS_SECOND_ROUND;		
		roundMaxUnits[3] = MAX_UNITS_THIRD_ROUND;		
	}

	function startBattle(address opponent, uint[3] calldata troopsAmount) public{
		require(currentlyFighting[msg.sender][opponent] == 0, "Use requestBattle");
		require(troopsAmount[0] <= PREDATOR_UNITS,"Exceeds Predators max");
		require(troopsAmount[1] <= PROXIMUS_COBRA_UNITS,"Exceeds Proximus Cobra max");
		require(troopsAmount[2] <= BOUNTY_HUNTERS_UNITS,"Exceeds Bounty Hunter max");

		_battleIds.increment();
		
		BattleData memory data = BattleData(
			msg.sender, //Creator
			opponent, //Opponnent
			FIRST_ROUND, //currentRound
			opponent, //NextMove
			troopsAmount[0], //predatorAttackingUnits
			troopsAmount[1], //proximusAttackingUnits
			troopsAmount[2], //bountyAttackingUnits
			0, //predatorDefendingUnits
			0, //proximusDefendingUnits
			0, //bountyDefendingUnits
			STARTING_LIFE, //creatorCityLife
			STARTING_LIFE //opponentCityLife
			);

		setBattle(_battleIds.current(), data);
		currentlyFighting[msg.sender][opponent] = _battleIds.current();
				
		emit RoundStarted(_battleIds.current(), data.currentRound);
	}

	//Troops amount for each type [predator, proximusCobra,bounty_hunters]	
	function requestBattle(uint id, uint[3] calldata troopsAmount) public{
		require(id <= _battleIds.current(),"Battle id doesn't exist");
		BattleData memory data = getBattleData(id);
		require(msg.sender == data.creator || msg.sender == data.opponent,"Can't request this battle");
		require(data.nextMove == msg.sender,"Not your turn!");
		require(troopsAmount[0] <= PREDATOR_UNITS,"Exceeds Predators max");
		require(troopsAmount[1] <= PROXIMUS_COBRA_UNITS,"Exceeds Proximus Cobra max");
		require(troopsAmount[2] <= BOUNTY_HUNTERS_UNITS,"Exceeds Bounty Hunter max");
		
		uint currentRound = data.currentRound;
		uint totalTroops = troopsAmount[0] + troopsAmount[1] + troopsAmount[2];

		require(totalTroops <= roundMaxUnits[currentRound],"Too many troops!");
		
		
		data = BattleData(
			data.creator,
			data.opponent,
			data.currentRound + 1, //currentRound
			data.nextMove == data.creator ? data.opponent : data.creator, //NextMove
			msg.sender == data.creator ? troopsAmount[0] : 0, //predatorAttackingUnits
			msg.sender == data.creator ? troopsAmount[1] : 0, //proximusAttackingUnits
			msg.sender == data.creator ? troopsAmount[2] : 0, //bountyAttackingUnits
			msg.sender == data.opponent ? troopsAmount[0] : 0, //predatorDefendingUnits
			msg.sender == data.opponent ? troopsAmount[1] : 0, //proximusDefendingUnits
			msg.sender == data.opponent ? troopsAmount[2] : 0, //bountyDefendingUnits
			STARTING_LIFE, //creatorCityLife
			STARTING_LIFE //opponentCityLife
			);
		setBattle(id, data);
				
		emit RoundStarted(id, data.currentRound);
	}

	//Troops amount for each type [predator,proximusCobra,bounty_hunters]
	function respondBattle(uint id,uint[3] calldata troopsAmount) external returns(address){
		require(id <= _battleIds.current(),"Battle id doesn't exist");
		BattleData memory data = getBattleData(id);
		require(msg.sender == data.creator || msg.sender == data.opponent,"Can't request this battle");
		require(data.nextMove == msg.sender,"Not your turn!");
		require(troopsAmount[0] <= PREDATOR_UNITS,"Exceeds Predators max");
		require(troopsAmount[1] <= PROXIMUS_COBRA_UNITS,"Exceeds Proximus Cobra max");
		require(troopsAmount[2] <= BOUNTY_HUNTERS_UNITS,"Exceeds Bounty Hunter max");

		if (msg.sender == data.creator){
			data.predatorAttackingUnits = troopsAmount[0];
			data.proximusAttackingUnits = troopsAmount[1];
			data.bountyAttackingUnits = troopsAmount[2];
		}else{
			data.predatorDefendingUnits = troopsAmount[0];
			data.proximusDefendingUnits = troopsAmount[1];
			data.bountyDefendingUnits = troopsAmount[2];
		}
		
		return resolveRound(id, data);
	}

	//Resolves round
	//If last round, returns winner, if not 0x000...
	function resolveRound (uint id, BattleData memory data) internal returns(address) {		
		uint creatorCurrentCityLife = data.creatorCityLife;
		uint opponentCurrentCityLife = data.opponentCityLife;
		//Creator
		uint creatorTotalAttack = data.predatorAttackingUnits * predator.attack + data.proximusAttackingUnits * proximusCobra.attack + data.bountyAttackingUnits * bounty_hunters.attack;
		uint creatorTotalDefense = data.predatorAttackingUnits * predator.defense + data.proximusAttackingUnits * proximusCobra.defense + data.bountyAttackingUnits * bounty_hunters.defense;
		//Opponent
		uint opponentTotalAttack = data.predatorDefendingUnits * predator.attack + data.proximusDefendingUnits * proximusCobra.attack + data.bountyDefendingUnits * bounty_hunters.attack;
		uint opponentTotalDefense = data.predatorDefendingUnits * predator.defense + data.proximusDefendingUnits * proximusCobra.defense + data.bountyDefendingUnits * bounty_hunters.defense;

		BattleData memory newData = BattleData(
			data.creator,
			data.opponent,
			data.currentRound == THIRD_ROUND ? 0 : data.currentRound + 1, //currentRound
			data.nextMove,
			0, //predatorAttackingUnits
			0, //proximusAttackingUnits
			0, //bountyAttackingUnits
			0, //predatorDefendingUnits
			0, //proximusDefendingUnits
			0, //bountyDefendingUnits
			getRemainingLife(creatorCurrentCityLife, getTotalDamage(opponentTotalAttack, creatorTotalDefense)), //creatorCityLife
			getRemainingLife(opponentCurrentCityLife, getTotalDamage(creatorTotalAttack, opponentTotalDefense)) //opponentCityLife
		);
		
		if (data.currentRound == THIRD_ROUND){
			address winner = newData.creatorCityLife >= newData.opponentCityLife ? data.creator : data.opponent;
			currentlyFighting[data.creator][data.opponent] = 0;
			emit RoundFinished(id, data.currentRound);
			emit BattleFinished(id, winner, winner == data.creator ? newData.creatorCityLife : newData.opponentCityLife, winner == data.opponent ? newData.creatorCityLife : newData.opponentCityLife);
			return winner;
		}
		
		setBattle(id, newData);
		emit RoundFinished(id, data.currentRound);				
		return(address(0));
	}
	
	function getTotalDamage(uint attack, uint defense) internal pure returns(uint){
		unchecked {
			return attack - defense;
		}
	}
	
	function getRemainingLife(uint currentLife, uint damage) internal pure returns(uint){
		unchecked {
			return currentLife - damage;
		}
	}

	function getBattleData(uint id) public view returns(BattleData memory){
		return battle[id];
	}

	function getCurrentRound(uint id) public view returns(uint currentRound){
		return battle[id].currentRound;
	}

	function setBattle(uint id,BattleData memory data) internal{
		battle[id] = data;
	}

	function setCurrentlyFighting(uint id,address creator,address opponent) internal{
		currentlyFighting[creator][opponent] = id;
	}
}