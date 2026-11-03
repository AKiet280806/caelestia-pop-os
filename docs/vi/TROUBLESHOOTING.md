# Khắc phục lỗi

[English](../en/TROUBLESHOOTING.md) · [Khôi phục](MAINTENANCE.md) · [Cài đặt](INSTALL.md)

Bắt đầu từ log và thông tin thực tế. Giữ COSMIC để làm việc trong lúc sửa Hyprland. Không chữa lỗi bằng cách thay Python hệ thống, chép thư viện tùy ý vào `/usr/lib`, xuất đường dẫn Qt riêng ra toàn hệ thống, mask toàn bộ portal hoặc cho APT gỡ thành phần Pop!_OS.

## Thu thập thông tin

Chạy trong thư mục repo:

```bash
./setup.sh preflight --json
./setup.sh doctor --json
cat /etc/os-release
hyprctl version
hyprctl monitors
systemctl --user status caelestia-shell.service --no-pager
journalctl --user -u caelestia-shell.service -b -n 100 --no-pager
tail -n 100 "$HOME/.local/state/caelestia-pop-os/session.log"
```

`hyprctl` cần phiên Hyprland đang chạy; báo lỗi trong COSMIC/TTY là bình thường. Một số kiểm tra chỉ có ý nghĩa sau đăng nhập. Khi báo lỗi, ghi bước cài, tùy chọn, GPU/driver và COSMIC có gặp cùng lỗi không. Xem lại trước khi đăng log, xóa token, thông tin tài khoản, đường dẫn dự án riêng và nội dung app không liên quan.

## Không vào được phiên

Nếu thiếu mục đăng nhập:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
ls -l /usr/local/bin/caelestia-pop-os-session
ls -l "$HOME/.local/bin/start-caelestia-session"
command -v Hyprland
```

Wrapper trong `Exec=` phải tồn tại, thực thi được và dẫn đến wrapper của đúng người dùng. Deploy dở có thể để lại tên phiên nhưng thiếu runtime. Chạy `doctor`, sửa bước bị lỗi rồi mới deploy lại sau khi đọc cách backup. Nếu automatic login bỏ qua menu phiên, tự tắt trong COSMIC Settings. Không restart display manager khi đang làm việc.

Nếu màn hình đen hoặc vừa đăng nhập đã quay lại greeter, nhấn **Ctrl+Alt+F3**, đăng nhập màn hình chữ và đọc `~/.local/state/caelestia-pop-os/session.log`. Khi phiên đồ họa khả dụng, quay về greeter/COSMIC; số phím console có thể khác theo hệ thống. Không giết các phiên/tiến trình không liên quan. Xem [khôi phục](MAINTENANCE.md).

## APT đòi gỡ gói hoặc không thấy bản được ghim

Dừng tại bước packages. Xem thông tin mà chưa cài gì:

```bash
apt-cache policy hyprland hyprland-dev system76-power pop-desktop cosmic-greeter
apt-mark showhold
dpkg --audit
```

Compositor và headers phải khớp phiên bản. PPA có thể thay đổi hoặc không còn giữ gói; trường hợp mất pin cần cập nhật pin có kiểm tra, không tự thêm `--allow-downgrades`, nâng compositor tùy ý hoặc gỡ COSMIC. Đối chiếu `pins.json`, bước packages và metadata APT. Giữ các gói System76/NVIDIA; không thêm `power-profiles-daemon` chỉ vì hướng dẫn upstream có tên đó.

## Biên dịch lỗi, hết RAM hoặc thiếu dung lượng

```bash
free -h
df -h "$HOME" /opt /tmp
./setup.sh preflight
```

Đọc lỗi compiler/configure đầu tiên, không chỉ dòng cuối `ninja failed`. Dùng `--jobs 1` nhất quán khi chạy lại nếu thiếu RAM. Chọn cache riêng trên phân vùng lớn hơn bằng `--cache-dir`. Không xóa checkout nguồn đang có sửa đổi: lưu thay đổi hoặc dùng cache dự án mới. Script cố ý từ chối source bẩn/sai pin/checksum. `clean-cache --dry-run` cho biết phạm vi dọn; không gỡ runtime đã cài và không giữ trạng thái compile đang dở.

## Mất shell, lỗi QML, icon vuông hoặc visualizer không chạy

```bash
systemctl --user status caelestia-shell.service --no-pager
journalctl --user -u caelestia-shell.service -b -n 120 --no-pager
ls -ld /opt/qt6 /opt/caelestia-wayland
fc-match Rubik
fc-match 'Material Symbols Rounded'
fc-match 'CaskaydiaCove NF'
fc-cache -f
```

Qt riêng phải có đủ QML module; Quickshell, m3shapes và plugin shell phải build bằng cùng toolchain. Xem `installer/runtime.sh`, chạy lại thành phần/bước bị lỗi. Không chữa QML import bằng symlink sang plugin Qt hệ thống không cùng phiên bản. Cava cần cả lệnh và libcava với PipeWire hoạt động; bản noncurses cần `libtool` khi build.

`caelestia-shell.service` do phiên quản lý; không enable toàn cục để chạy cả trong COSMIC. Sau khi sửa, restart shell có thể đóng UI; lưu công việc và bảo đảm đang mở khóa trước khi chủ động restart.

## NVIDIA, scale hoặc màn hình ngoài lỗi

Xem `nvidia-smi`, modeset DRM, `lspci -nnk`, `/dev/dri/by-path/`, `hyprctl monitors` và log. NVIDIA độc quyền cần modeset `Y`. Giữ driver Pop!_OS cung cấp. Kiểm tra `~/.config/caelestia-pop-os/profile.json`, `profile.env` và `~/.config/hypr/hyprland.lua`; không ép chỉ số GPU của máy người khác.

Scale mặc định 1.0; 1.5 mới được thử trên một màn 14 inch 2560×1600. Một scale phù hợp màn này có thể sai màn khác. Sao lưu, đổi từng mục rồi kiểm tra theo API cấu hình Hyprland 0.57. Không dán cú pháp `.conf` đời cũ vào cấu hình Lua. Nhiều màn hình, hybrid và suspend cần kiểm tra phần cứng riêng.

## File chooser, chia sẻ màn hình hoặc app Flatpak lỗi

```bash
systemctl --user list-units 'xdg-desktop-portal*' --all
journalctl --user -b --no-pager | grep -i 'portal' | tail -n 80
printf '%s\n' "$XDG_CURRENT_DESKTOP" "$XDG_SESSION_TYPE"
cat "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
```

Dùng lựa chọn portal theo desktop trong `configs/xdg-desktop-portal/`. COSMIC và Hyprland cần backend phù hợp từng phiên. Không mask portal COSMIC/GTK toàn cục để ép một backend. Đăng xuất/đăng nhập lại sau khi sửa môi trường phiên. Chia sẻ màn hình của browser và quay trực tiếp bằng wf-recorder là hai cơ chế khác nhau.

## Clipboard, tiếng Việt hoặc độ sáng không hoạt động

Clipboard: xem helper khởi động phiên và `systemctl --user list-units 'caelestia-clipboard@*' --all`. Copy văn bản mới sau khi watcher chạy rồi thử Win+Shift+V. Nội dung cũ có thể chưa được ghi lại.

Tiếng Việt: chạy `pgrep -a fcitx5`, `fcitx5-remote -n`, `fcitx5-diagnose` trong Hyprland. Kiểm tra gói Unikey, danh sách input method, engine đang chọn, phím bật/tắt và Telex. Chỉ dùng `scripts/start-fcitx-unikey` trong phiên cần nó. App Qt riêng/Flatpak có thể cần module bộ gõ khớp; giữ biến môi trường bộ gõ trong phiên.

Độ sáng: xem `brightnessctl --list` và `ddcutil detect`. Đèn nền laptop khác điều khiển DDC/CI của màn ngoài. Gói `brightness-udev` cung cấp quyền phù hợp; không chmod thiết bị cho mọi người ghi hoặc chạy desktop bằng root. Một số màn ngoài không hỗ trợ DDC/CI.

## Quay lỗi hoặc không có tiếng

```bash
command -v wf-recorder ffmpeg
ffmpeg -hide_banner -encoders | grep -E 'libx264|h264_nvenc'
wpctl status
pactl get-default-sink
pactl list short sources
```

Kiểm tra dung lượng tại `~/Videos/Recordings`. Nguồn âm thanh là monitor của output sink; khi ngắt thiết bị có thể không còn monitor hoạt động. Đổi tai nghe/loa có thể đổi sink. Nếu NVENC lỗi, chọn `--encoder libx264` qua cấu hình trình cài để thử. Không sửa trực tiếp gói Python đã cài; nguồn recorder ở `src/cli-overrides/record.py`. Pause không được hỗ trợ với wf-recorder.

## Khóa màn hình hoặc suspend không ổn định

Ban đầu tắt tự idle và vân tay. Thử Win+L/mở khóa mật khẩu khi còn đường về TTY/COSMIC. Xem PAM/log lock trước khi bật idle/suspend. Có cảm biến vân tay chưa có nghĩa xác thực đã hoạt động. Sleep/wake chưa được xác nhận cho mọi GPU.

## Widget Codex không có số liệu

Kiểm tra lệnh `codex` chính thức có trong PATH của phiên và đã đăng nhập tài khoản của bạn. Xem trạng thái backend mà không chép credential. RPC không trả quota, login hết hạn, tài khoản không hỗ trợ hoặc dữ liệu cũ phải hiện unavailable/stale; không suy ra hạn mức ChatGPT chat thường. Khi báo lỗi, chỉ gửi trạng thái/phiên bản đã lược thông tin riêng, không gửi `auth.json`, token hoặc cả thư mục trạng thái Codex.
