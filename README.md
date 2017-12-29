# Slurm expand

Small program which produces a machine file from the value of a few SLURM
environment variables.


## Installation

The program is written in [Nim](https://nim-lang.org/), so you must install the
compiler first. Once you have `nim` in your path, run

    nim c slurmexpand.nim

to create the executable.


## Usage

Within your SLURM job, run

    slurmexpand > slurm_machines

to create a machine file in `slurm_machines`. This file can be used by
multiprocess programs like [Julia](https://julialang.org/):

    julia --machinefile slurm_machines
