#!/usr/bin/env bash
set -euo pipefail

guest_root="${XL_GUEST_ROOT:-/guest}"
host_data_dir="${XL_HOST_DATA_DIR:-/xunlei/data}"
host_cache_dir="${XL_HOST_CACHE_DIR:-/xunlei/var/packages/pan-xunlei-com}"
download_paths="${XL_DIR_DOWNLOAD:-/xunlei/downloads}"

mkdir -p \
  "${guest_root}" \
  "${guest_root}/etc" \
  "${guest_root}/proc" \
  "${guest_root}/dev" \
  "${guest_root}/tmp" \
  "${guest_root}/run" \
  "${guest_root}/sys" \
  "${guest_root}/usr/syno/synoman/webman/modules" \
  "${guest_root}/var/packages/pan-xunlei-com" \
  "${guest_root}/xunlei/data" \
  "${host_data_dir}" \
  "${host_cache_dir}"

proot_args=(
  -r "${guest_root}"
  -w /
  -0
  -b /proc:/proc
  -b /dev:/dev
  -b /sys:/sys
  -b /tmp:/tmp
  -b /run:/run
  -b /bin:/bin
  -b /lib:/lib
  -b /usr:/usr
  -b "${host_data_dir}:/xunlei/data"
  -b "${host_cache_dir}:/var/packages/pan-xunlei-com"
)

if [[ -e /lib64 ]]; then
  proot_args+=(-b /lib64:/lib64)
fi

if [[ -e /etc/ssl ]]; then
  proot_args+=(-b /etc/ssl:/etc/ssl)
fi

for path in \
  /etc/group \
  /etc/hosts \
  /etc/hostname \
  /etc/localtime \
  /etc/nsswitch.conf \
  /etc/passwd \
  /etc/resolv.conf \
  /etc/shadow \
  /etc/timezone
do
  if [[ -e "${path}" ]]; then
    proot_args+=(-b "${path}:${path}")
  fi
done

IFS=':' read -r -a download_bindings <<< "${download_paths}"
for download_path in "${download_bindings[@]}"; do
  [[ -n "${download_path}" ]] || continue

  mkdir -p "${download_path}" "${guest_root}${download_path}"
  proot_args+=(-b "${download_path}:${download_path}")
done

exec proot "${proot_args[@]}" /xlp "$@"
