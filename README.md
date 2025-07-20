# My DVDeFi Journey
**Goal:** Become a web3 security researcher by solving all challenges

## Progress
- 1/15 challenges solved
-  Current focus: Naive receiver

## Key Lessons
-  Reentrancy: Always lock state before external calls
-  Flash loans: Never trust on-chain prices mid-transaction


## how i solve these challenges
1. look at the challenge's README.md to understand what is the objective and to get a rough idea of the challenge
2. Check out the test file to get an even clearer idea of what is being tested, so we can write the solution under the conditions specified in the test file
3. Review the main contract: quickly scan the entire contract then focus on high-risk areas(functions like flashloan, transfer or access control)
4. start by checking crucial points (conditions, input parameters, calculations). Take time on suspicious areas. make sure every bit of it make sense until we find where it doesn't
5. code the solution in the test file and write code annotations

[Full solutions in `/test`]



## solving order
1. Unstoppable
2. Naive receiver
3. Truster
4. Side Entrance
5. The Rewarder
6. Selfie
7. Compromised
8. Puppet
9. Puppet V2
10. Free rider
11. backdoor
12. climber
13. wallet mining
14. puppet v3
15. ABI smuggling
16. shards
17. curvy puppet
18. withdrawal


## contributing
Your feedback is gold! If something seems off, I’d really appreciate a PR, it helps a ton🙌