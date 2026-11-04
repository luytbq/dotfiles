#!/bin/bash

mvn_test() {
    if [ -z "$1" ]; then
        echo "Usage: mvn_test <TestClassName>"
        return 1
    fi
    echo "mvn test -DskipTests=false -Dtest=$1"
    mvn test -DskipTests=false -Dtest="$1"
}

mvn_exec() {
    if [ -z "$1" ]; then
        echo "Usage: mvn_exec <MainClassName>"
        return 1
    fi
    echo "mvn exec:java -Dexec.mainClass=$1"
    mvn exec:java -Dexec.mainClass="$1"
}
