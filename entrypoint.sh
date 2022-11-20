#!/bin/bash

set -o pipefail


echo "dbt project folder set as: \"${INPUT_DBT_PROJECT_FOLDER}\""
cd ${INPUT_DBT_PROJECT_FOLDER}

if [ -n "${DBT_BIGQUERY_TOKEN}" ]
then
  echo trying to parse bigquery token
  $(echo ${DBT_BIGQUERY_TOKEN} | base64 -d > ./creds.json 2>/dev/null)
  if [ $? -eq 0 ]
  then
    echo success parsing base64 encoded token
  elif $(echo ${DBT_BIGQUERY_TOKEN} > ./creds.json)
  then
    echo success parsing plain token
  else
    echo cannot parse bigquery token
    exit 1
  fi
elif [ -n "${DBT_USER}" ] && [ -n "$DBT_PASSWORD" ]
then
 echo trying to use user/password
 sed -i "s/_user_/${DBT_USER}/g" ./profiles.yml
 sed -i "s/_password_/${DBT_PASSWORD}/g" ./profiles.yml
elif [ -n "${DBT_TOKEN}" ]
then
 echo trying to use DBT_TOKEN/databricks
 sed -i "s/_token_/${DBT_TOKEN}/g" ./datab.yml
else
  echo no tokens or credentials supplied
fi

DBT_ACTION_LOG_FILE=${DBT_ACTION_LOG_FILE:="dbt_console_output.txt"}
DBT_ACTION_LOG_PATH="${INPUT_DBT_PROJECT_FOLDER}/${DBT_ACTION_LOG_FILE}"
echo "DBT_ACTION_LOG_PATH=${DBT_ACTION_LOG_PATH}" >> $GITHUB_ENV
echo "saving console output in \"${DBT_ACTION_LOG_PATH}\""
# final_state=0
result=$(git diff --name-status origin/main origin/${PR_BRANCH} |grep -v zettablock_data_mart|grep -v macros|grep -v trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-)

# dbt build --target dev --profiles-dir ./dryrun_profile --project-dir ./zettablock --select models/cryptocom_data/aave/ethereum/aave_v2_ethereum_account_positions.sql models/cryptocom_data/aave/ethereum/aave_v2_ethereum_atoken_positions.sql models/cryptocom_data/aave/ethereum/aave_v2_ethereum_atoken_transfers.sql models/cryptocom_data/aave/ethereum/aave_v2_ethereum_debt_token_positions.sql models/cryptocom_data/aave/ethereum/aave_v2_ethereum_tokens.sql models/cryptocom_data/ethereum/ethereum_stablecoin_transfer.sql models/cryptocom_data/explore/explore_top_aave_profit_takers_12_months.sql models/cryptocom_data/explore/explore_top_stablecoin_flows.sql models/cryptocom_data/explore/explore_uniswap_v3_ethereum_trades.sql models/cryptocom_data/explore/explore_uniswap_v3_pool_volumes.sql models/cryptocom_data/explore/explore_uniswap_v3_trader_profits_per_token.sql models/cryptocom_data/explore/explore_uniswap_v3_trader_profits_total.sql models/cryptocom_data/uniswap/ethereum/uniswap_v3_ethereum_account_positions.sql models/cryptocom_data/uniswap/ethereum/uniswap_v3_ethereum_pool_liquidity.sql --vars '{"external_s3_location":"s3://my-897033522173-us-east-1-spark/demo/b46b2d72c96061a8/"}'

if [[ $? != 0 ]]; then
    echo "Check delta files failed."
elif [[ $result ]]; then
    tasks=( $(git diff --name-status origin/main origin/${PR_BRANCH} |grep -v zettablock_data_mart|grep -v macros|grep -v trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-) )
    echo '---------------------------------------------------------'
    echo "${tasks[@]}"
    echo "dbt build --target dev --profiles-dir ./dryrun_profile --project-dir ./zettablock --select ${tasks[@]} --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)/\"}'" 
    echo '---------------------------------------------------------'
    echo "dbt build --target dev --profiles-dir ./dryrun_profile --project-dir ./zettablock --select ${tasks[@]} --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)/\"}'" |bash
    if [ $? -ne 0 ]
        then
            echo "exception."
            exit 255
    fi
else
    echo "No active change found."
fi

trino_result=$(git diff --name-status origin/main origin/${PR_BRANCH} |grep -v zettablock_data_mart|grep -v macros|grep trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-)
if [[ $? != 0 ]]; then
    echo "Check trino delta files failed."
elif [[ $trino_result ]]; then
    tasks=( $(git diff --name-status origin/main origin/${PR_BRANCH} |grep -v zettablock_data_mart|grep -v macros|grep trino|grep 'sql$'|grep -v '^D'|cut  -f2 |cut -d'/' -f2-) )
    echo '========================================================='
    echo $tasks
    echo "dbt build --target dev --profiles-dir ./trino_profile --project-dir ./zettablock --select ${tasks[@]} --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)/\", \"TRINO_USER\":\"'\"$TRINO_USER\"'\", \"TRINO_PASSWORD\":\"'\"$TRINO_PASSWORD\"'\", \"TRINO_HOST\":\"'\"$TRINO_HOST\"'\"}'"
    echo '========================================================='
    echo "dbt build --target dev --profiles-dir ./trino_profile --project-dir ./zettablock --select ${tasks[@]} --vars '{\"external_s3_location\":\"s3://my-897033522173-us-east-1-spark/demo/$(openssl rand -hex 8)/\", \"TRINO_USER\":\"'\"$TRINO_USER\"'\", \"TRINO_PASSWORD\":\"'\"$TRINO_PASSWORD\"'\", \"TRINO_HOST\":\"'\"$TRINO_HOST\"'\"}'"| bash
    if [ $? -ne 0 ]
        then
            echo "exception."
            exit 255
    fi
else
    echo "No active change found."
fi
