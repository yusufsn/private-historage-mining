# historage-mining
A tool to collect historical metrics from a historage repository.

## How to
1. Create directories
    > mkdir historage-mining/historage historage-mining/result
1. Put a historage repository in the directory **historage**
    * Clone an exisint repository from [Codosseum](http://codosseum.naist.jp/) [recommended], or
    * Use [kenja](https://github.com/niyaton/kenja) to create by yourself
1. Set parameters in **GetMetrics.sh**
    * reddit -> *your historage repository*
    * e4bd50addbb9223cd56e4f2fe141d2674df11fca -> *target commit ID*
    * 2017-01-03 -> *date of your target commit ID*
1. Run **GetMetrics.sh**
