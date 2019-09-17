#!/bin/bash -e

    function env-var-exists() {
      if [ -z "${1}" ]; then
        echo "Please specify environment variable name to check"
        exit 1
      fi
      if [ -z "${!1}" ]; then
        echo "Environment variable '${1}' is not set"
        exit 1
      fi
    }

    # Create or replace config value in specified PostgreSQL config file
    # ${1}  parameter name
    # ${2}  parameter value
    # ${3}  config file path
    function create_or_replace_config_value() {
      if grep -qF "${1}" "${3}"; then
        sed -ri "s|^#?(${1})\s*=\s*[0-9a-zA-Z\x20\x22\x25\x27\x2A\x2C\x2E/=_-]+(\s*#.*)?|\1 = ${2}\2|" "${3}"
      else
        echo "${1} = ${2}" >> "${3}"
      fi
    }

    function parse_external_configuration() {
      OIFS=$IFS
      IFS=' = '
      declare -A config_array
      declare -a keys=()
      declare -a vals=()
      while  read -r key val; do
        [[ $key = '#'* ]] && continue
        config_array["$key"]="$val"
      done <<<$(cat /pgconf/env.sh)
      #${EXTERNAL_CONFIGURATION}

      for key in "${!config_array[@]}"; do
        echo ${key} " =" "'${config_array[$key]}'"
      done
      echo "========================"

      memory_limit=$(get_memory_limit_in_mb)
      echo "Original memory limit is "$memory_limit
      cpu_limit=$(get_cpu_limit_in_cores)
      echo "CPU limit in cores is "$cpu_limit
      # shared_buffers
      if [ ${config_array[shared_buffers]+_} ]; then
        echo "shared_buffers is provided by the user ${config_array[shared_buffers]}"
        shared_buffers=$(echo ${config_array[shared_buffers]} | grep -o -E '[0-9]+')
        if [[ ${config_array[shared_buffers]} == *"GB" ]]; then
          multiplier=1024
        elif [[ ${config_array[shared_buffers]} == *"MB" ]]; then
          multiplier=1
        fi
        memory_limit=$(expr $memory_limit - $shared_buffers \* $multiplier)
        echo "New memory limit is - "$memory_limit
      fi
      # effective_cache_size
      if [ ${config_array[effective_cache_size]+_} ]; then
        echo "effective_cache_size is provided by the user ${config_array[effective_cache_size]}"
        effective_cache_size=$(echo ${config_array[effective_cache_size]} | grep -o -E '[0-9]+')
        if [[ ${config_array[effective_cache_size]} == *"GB" ]]; then
          multiplier=1024
        elif [[ ${config_array[effective_cache_size]} == *"MB" ]]; then
          multiplier=1
        fi
        memory_limit=$(expr $memory_limit - $effective_cache_size \* $multiplier)
        echo "New memory limit is - "$memory_limit
      fi
      # max_connections
      if [ ${config_array[max_connections]+_} ]; then
        echo "max_connections is provided by the user ${config_array[max_connections]}"
      else
        ${config_array[max_connections]}=100
      fi
      # work_mem
      if [ ${config_array[work_mem]+_} ]; then
        echo "work_mem is provided by the user ${config_array[work_mem]}"
        work_mem=$(echo ${config_array[work_mem]} | grep -o -E '[0-9]+')
        memory_limit=$(expr $memory_limit - $work_mem / 1024 \* ${config_array[max_connections]})
        echo "New memory limit is - "$memory_limit
      fi
      # maintenance_work_mem
      if [ ${config_array[maintenance_work_mem]+_} ]; then
        echo "maintenance_work_mem is provided by the user ${config_array[maintenance_work_mem]}"
        maintenance_work_mem=$(echo ${config_array[maintenance_work_mem]} | grep -o -E '[0-9]+')
        memory_limit=$(expr $memory_limit - $maintenance_work_mem \* $cpu_limit)
        echo "New memory limit is - "$memory_limit
      fi

      # shared_buffers
      if [ ! ${config_array[shared_buffers]+_} ]; then
        echo "Setting up shared_buffers"
        config_array[shared_buffers]=$(echo $(expr $memory_limit / 4)MB)
      fi
      # effective_cache_size
      if [ ! ${config_array[effective_cache_size]+_} ]; then
        echo "Setting up effective_cache_size"
        config_array[effective_cache_size]=$(echo $(expr $memory_limit / 2)MB)
      fi
      # work_mem
      if [ ! ${config_array[work_mem]+_} ]; then
        echo "Setting up work_mem"
        config_array[work_mem]=$(echo $(expr $memory_limit \* 1024 / 4 / ${config_array[max_connections]})kB)
      fi
      # maintenance_work_mem
      if [ ! ${config_array[maintenance_work_mem]+_} ]; then
        echo "Setting up maintenance_work_mem"
        maintenance_work_mem=$(expr $memory_limit / 20)
        if [ $maintenance_work_mem -ge 64 ]; then
          config_array[maintenance_work_mem]='64MB'
          echo "maintenance_work_mem is way too big"
        else
          config_array[maintenance_work_mem]=$(echo $maintenance_work_mem'MB')
        fi
      fi
      echo "============================="
      for key in "${!config_array[@]}"; do
        echo ${key} " =" "'${config_array[$key]}'"
      done

      for key in "${!config_array[@]}"; do
        create_or_replace_config_value ${key} "'${config_array[$key]}'" ${PGDATA}/postgresql.conf
      done
      IFS=$OIFS
    }

    function get_memory_limit_in_mb() {
        echo `expr $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes) / 1048576`
#        return `expr $(cat /sys/fs/cgroup/memory/memory.limit_in_bytes) / 1048576`
    }

    function get_cpu_limit_in_cores() {
        period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
        quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us)
        echo $(expr $quota / $period)
#        return $(expr $quota / $period)
    }

    function calculate_mem_paramaters() {
#        set -x
        memory_limit=$(get_memory_limit_in_mb)
        shared_buffers=$(echo $(expr $memory_limit / 4)MB)
        echo "Shared_buffers could be >>>> "$shared_buffers
        effective_cache_size=$(echo $(expr $memory_limit / 2)MB)
        echo "effective_cache_size could be >>>> "$effective_cache_size
        work_mem=$(echo $(expr $memory_limit \* 1024 / 4 / 100)kB)
        echo "work_mem could be >>>> "$work_mem
        maintenance_work_mem=$(echo $(expr $memory_limit / 10)MB)
        echo "maintenance_work_mem could be >>>> "$maintenance_work_mem
#        set +x
    }

    env-var-exists POSTGRESQL_TYPE

    declare -a TYPES=("admindb" "dw" "realtimedb")
    if [[ ! "${TYPES[@]}" =~ "${POSTGRESQL_TYPE}" ]]; then
      echo "$(date '+%F %T') ${0}: FATAL: Type \"${POSTGRESQL_TYPE}\" is not supported"
      exit 1
    fi

    echo "$(date '+%F %T') ${0}: Setting main config values..."
    calculate_mem_paramaters
    parse_external_configuration

    case "${POSTGRESQL_TYPE}" in
      "admindb")
        shared_preload_libraries="pg_cron, pg_stat_statements, pg_stat_kcache"
      ;;
      "dw")
        shared_preload_libraries="citus, cstore_fdw, pg_cron, pg_partman_bgw, pg_stat_statements, pg_stat_kcache"
      ;;
      "realtimedb")
        shared_preload_libraries="cstore_fdw, pg_cron, pg_partman_bgw, pg_stat_statements, pg_stat_kcache"
      ;;
    esac
    create_or_replace_config_value 'shared_preload_libraries' "'${shared_preload_libraries}'" ${PGDATA}/postgresql.conf

    case "${POSTGRESQL_TYPE}" in
      "dw")
        create_or_replace_config_value 'citus.enable_statistics_collection' "off" ${PGDATA}/postgresql.conf
      ;;
    esac

    create_or_replace_config_value 'cron.database_name' "'${PG_DATABASE}'" ${PGDATA}/postgresql.conf

    case "${POSTGRESQL_TYPE}" in
      "dw"|"realtimedb")
        create_or_replace_config_value 'pg_partman_bgw.role' "'${PG_USER}'" ${PGDATA}/postgresql.conf
        create_or_replace_config_value 'pg_partman_bgw.dbname' "'${PG_DATABASE}'" ${PGDATA}/postgresql.conf
      ;;
    esac

    echo "Updating pg_hba.conf file"
    sed  -i "s/^#host\s*all\s*all\s*::1\/128\s*trust/host\tall\tall\t::1\/128\ttrust/" ${PGDATA}/pg_hba.conf

    echo "$(date '+%F %T') ${0}: Setting main config values - DONE"
