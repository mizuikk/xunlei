#!/usr/bin/env bash
set -euo pipefail

guest_root="${XL_GUEST_ROOT:-/guest}"
host_data_dir="${XL_HOST_DATA_DIR:-/xunlei/data}"
host_cache_dir="${XL_HOST_CACHE_DIR:-/xunlei/var/packages/pan-xunlei-com}"
download_paths="${XL_DIR_DOWNLOAD:-/xunlei/downloads}"
fake_proc_root="${XL_FAKE_PROC_ROOT:-/tmp/xlp-fake-proc}"

link_fake_proc() {
  local source_path="$1"
  local target_path="$2"

  [[ -e "${source_path}" ]] || return 0

  mkdir -p "$(dirname "${target_path}")"
  ln -snf "${source_path}" "${target_path}"
}

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

rm -rf "${fake_proc_root}"
mkdir -p "${fake_proc_root}/self" "${fake_proc_root}/1"

# Pan CLI will reject the Synology profile once it sees Docker overlay mounts.
# Keep the proc files it needs, but replace the mount and cgroup views.
for path in cpuinfo loadavg meminfo stat uptime version filesystems vmstat diskstats swaps interrupts kcore keys timer_list; do
  link_fake_proc "/host-proc/${path}" "${fake_proc_root}/${path}"
done

for path in net sys; do
  link_fake_proc "/host-proc/${path}" "${fake_proc_root}/${path}"
done

for path in auxv cmdline cwd environ exe fd fdinfo maps root stat status task ns; do
  link_fake_proc "/host-proc/self/${path}" "${fake_proc_root}/self/${path}"
done

for path in cmdline environ exe fd fdinfo maps root stat status task ns; do
  link_fake_proc "/host-proc/1/${path}" "${fake_proc_root}/1/${path}"
done

cat >"${fake_proc_root}/mounts" <<'EOF'
/dev/root / ext4 rw 0 0
proc /proc proc rw 0 0
EOF
cp "${fake_proc_root}/mounts" "${fake_proc_root}/self/mounts"
cp "${fake_proc_root}/mounts" "${fake_proc_root}/1/mounts"

cat >"${fake_proc_root}/mountinfo" <<'EOF'
1 0 0:1 / / rw,relatime - rootfs rootfs rw
2 1 0:2 / /proc rw,relatime - proc proc rw
EOF
cp "${fake_proc_root}/mountinfo" "${fake_proc_root}/self/mountinfo"
cp "${fake_proc_root}/mountinfo" "${fake_proc_root}/1/mountinfo"

printf '0::/\n' >"${fake_proc_root}/self/cgroup"
cp "${fake_proc_root}/self/cgroup" "${fake_proc_root}/1/cgroup"

proot_args=(
  -r "${guest_root}"
  -w /
  -0
  -b /proc:/host-proc
  -b "${fake_proc_root}:/proc"
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
