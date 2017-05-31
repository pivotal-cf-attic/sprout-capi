function unclaim_bosh_lite() {

  # ensures we don't remove the current working directory
  if [[ "$PWD" == *capi-env-pool* ]]; then
    cd "$HOME/workspace/capi-env-pool"
  fi
  (
    set -e
    cd ~/workspace/capi-env-pool

    working_pool="bosh-lites"
    broken_pool="broken-bosh-lites"

    if [ $# -eq 0 ]; then
      echo 'Usage: $0 env_name'
      return 1
    fi

    git pull -r --quiet

    function mark_broken {
      env=$1
      file=`find ${working_pool} -name $env`

      if [ "$file" == "" ]; then
        echo "$env does not exist in ${working_pool}"
        return 1
      fi

      read -p "Hit enter to release $env "

      git mv $file "${broken_pool}/unclaimed/"
      git rm -rf "${env}" && rm -rf "${env}"
      git ci --quiet -m"releasing $env on ${HOSTNAME} [nostory]" --no-verify
      echo "Pushing the release commit to $( basename $PWD )..."
      git push --quiet
    }

    function trigger_cleanup_job {
      echo "Triggering delete-bosh-lite job..."

      set +e
      fly -t capi trigger-job -j bosh-lite/delete-bosh-lite
      exit_code="$?"
      set -e

      if [ "${exit_code}" != 0 ]; then
        fly -t capi login
        fly -t capi trigger-job -j bosh-lite/delete-bosh-lite
      fi

      echo "Triggering create-bosh-lite job..."
      fly -t capi trigger-job -j bosh-lite/create-bosh-lite
    }

    for env in "$@"; do
      mark_broken $env
    done

    trigger_cleanup_job
  )

  unset BOSH_CA_CERT BOSH_CLIENT BOSH_CLIENT_SECRET BOSH_ENVIRONMENT \
    BOSH_GW_USER BOSH_GW_HOST BOSH_LITE_DOMAIN BOSH_GW_PRIVATE_KEY_CONTENTS \
    BOSH_GW_PRIVATE_KEY

  echo "Done"
}

export -f unclaim_bosh_lite
