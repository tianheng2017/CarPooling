## Description of the proposed coordination mechanism implemented in the assignPassengersToRides() function (no more than 200 words):
- First, iterates through the list of awaitIds via a for loop and sorts them in ascending order of the passenger's desired departure time.
- Then we query the trips that match the passenger's start and end points via findRides, if there are no trips that match the conditions, then we refund the deposit in full, otherwise we calculate the time deviation of the passenger from each of these trips.
- Find the trip that corresponds to the smallest time deviation value, and if there are still seats left in that trip, assign the passenger to that trip and refund the difference between the deposit and the driver's unit price.
- If there is only one trip, the passenger is assigned to that trip regardless of the time deviation.
## Do you use any additional contract variables? If so, what is the purpose of each variable? (no more than 200 words):
- awaitIds: stores the ID groups of the passengers to be assigned.
- nextAwaitId: ID of the next passenger to be assigned.
- passengerWaitlist: a map storing the passenger's address, start point, end point, desired departure time, deposit, carpool ID, refund amount, and other information.

## Do you use any additional data structures (structs)? If so, what is the purpose of each structure? (no more than 200 words):
- PassengerWait structure: stores information such as passenger address, start point, end point, desired departure time, deposit, carpool ID, refund amount.
- Deviation: used to store the time deviation of the passenger from the trip.

## Do you use any additional contract functions? If so, what is the purpose of each function? (no more than 200 words):
- _joinRide: this function is a public passenger carpooling logic for easy code reuse, it is used in both joinRide and assignPassengersToRides.
- abs：计算两个数的绝对值

## Did you implement any additional test cases to test your smart contract? If so, what are these tests?
- awaitAssignRide function test: register user1 as a passenger, then user1 call awaitAssignRide, then determine whether the call is successful.
- assignPassengersToRides function test 1, assignPassengersToRides function test 2, assignPassengersToRides function test 3, assignPassengersToRides function test 4: these four functions use different test data to test the functional logic of assignPassengersToRides in multiple ways, and determine whether the results are consistent with expectations.