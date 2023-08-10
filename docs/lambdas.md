# Lambdas

This contract allows to associate lambdas with proposals.

The entrypoint `execute` allows a lambda to be executed once the proposal is accepted.

## Makefile helper

A helper has been made to help pack lambdas expressions and generate hashes:

1. Create a file inside the [./lambdas](./lambdas) directory
2. Run `F=./lambdas/my-lambda-filename.mligo make compile-lambda` to test it
3. Run `F=./lambdas/my-lambda-filename.mligo make pack-lambda` to get packed and hash parameters
