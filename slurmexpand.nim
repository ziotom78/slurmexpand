# Print a machine file given the value of the SLURM environment variables
# Maurizio Tomasi
# First version: 2017-12-29
#
# This program has been written using Nim 0.17.2 (https://nim-lang.org/)
# To compile it, install Nim and run the following command:
#
#    nim c slurmexpand.nim
#
# This program takes the value of the following environment variables and
# prints a machine file to stdout:
#   - SLURM_NODELIST
#   - SLURM_TASKS_PER_NODE
#
# A machine file is a text file containing one machine name per line. If
# many processes are to be spawn on the same machine, the machine name is
# repeated as many times as needed.
#
# To understand how the code works, refer to the implementation of the
# procedure "testEverything" below.

import os
import pegs
import sequtils
import strutils

proc expand_nodelist(str: string) : seq[string] =
    ## Expand a string containing the name of the nodes to be used into a
    ## sequence of strings. This is usually called with "str" equal to
    ## the value of the environment variable "SLURM_NODELIST".

    let sq_bk_open = find(str, '[')
    let sq_bk_close = find(str, ']')
    
    if sq_bk_open < 0 and sq_bk_close < 0:
        return @[str]

    assert(sq_bk_open >= 0 and sq_bk_close > sq_bk_open,
           "invalid string \"$1\"" % [str])

    result = @[]

    let range_str = str[(sq_bk_open + 1)..(sq_bk_close - 1)]
    var template_str = str
    template_str.delete(sq_bk_open, sq_bk_close)
    assert(find(range_str, '-') > 0,
           "no range found in string \"$1\"" % [str])

    let extremes = strutils.split(range_str, '-').map(parseInt)
    assert(len(extremes) == 2, "invalid range \"$1\" (in string \"$2\")" % [range_str, str])
    for cur_num in extremes[0]..extremes[1]:
        result.add(template_str[0..(sq_bk_open - 1)] & $cur_num & template_str[sq_bk_open..len(template_str)])


proc expand_tasks(str: string) : seq[int] =
    ## Expand a string containing the number of tasks per node into a
    ## sequence of integers. This is usually called with "str" equal to
    ## the value of the environment variable "SLURM_TASKS_PER_NODE".

    let elements = strutils.split(str, ',')

    result = @[]
    for cur_elem in elements:
        if cur_elem =~ peg"{\d+} '(x' {\d+} ')'":
            let nodes = parseInt(matches[0])
            let repeat = parseInt(matches[1])
            for i in 1..repeat:
                result.add(nodes)
        else:
            result.add(parseInt(cur_elem))


proc expand(nodelist_str, taskspernode_str: string) : seq[string] =
    ## Produce a sequence of machine names matching the values
    ## of SLURM_NODELIST and SLURM_TASKS_PER_NODE

    result = @[]

    let nodes = expand_nodelist(nodelist_str)
    let tasks = expand_tasks(taskspernode_str)

    assert(nodes.len == tasks.len,
           "mismatch between the number of nodes ($1) and tasks ($2)" % [$nodes.len, $tasks.len])
    
    for cur_idx in 0..(nodes.len - 1):
        for cur_proc_idx in 1..tasks[cur_idx]:
            result.add(nodes[cur_idx])


proc testEverything() =
    ## Run tests that check that every procedure defined above works as expected.

    assert(expand_nodelist("node10") == @["node10"])
    assert(expand_nodelist("node[5-6]") == @["node5", "node6"])
    assert(expand_nodelist("node[5-6]abc") == @["node5abc", "node6abc"])

    assert(expand_tasks("2") == @[2])
    assert(expand_tasks("12(x3)") == @[12, 12, 12])
    assert(expand_tasks("12(x2),7(x3),4") == @[12, 12, 7, 7, 7, 4])

    assert(expand("node5", "2") == @["node5", "node5"])
    assert(expand("node[5-6]", "2,1") == @["node5", "node5", "node6"])
    assert(expand("node[5-7]", "2(x2),1") == @["node5", "node5", "node6", "node6", "node7"])


proc main =
    # We play safe, and run the full test suite every time the program is invoked.
    # (We can do this, as the tests run very quickly.)
    testEverything()

    # Check that we are running within a SLURM process
    if (not existsEnv("SLURM_NODELIST")) or (not existsEnv("SLURM_TASKS_PER_NODE")):
        echo "Error: it does not seem I'm running within a SLURM job"
        quit(1)

    let nodelist_str = getEnv("SLURM_NODELIST")
    let taskspernode_str = getEnv("SLURM_TASKS_PER_NODE")

    let node_list = expand(nodelist_str=nodelist_str, taskspernode_str=taskspernode_str)

    for cur_node in node_list:
        echo cur_node

main()
