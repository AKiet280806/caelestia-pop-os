# Khôi phục, cập nhật và gỡ cài đặt

[English](../en/MAINTENANCE.md) · [Khắc phục lỗi](TROUBLESHOOTING.md) · [Dọn dung lượng](COSMIC-CLEANUP.md)

Trình cài giữ COSMIC và không tự thoát phiên đang dùng. Rollback cấu hình khác với gỡ phần mềm hệ thống.

## Quay về COSMIC

Lưu công việc. Trong Hyprland nhấn Win+Ctrl+Shift+Q để đăng xuất, mở menu chọn phiên tại COSMIC Greeter, chọn **COSMIC** rồi nhập mật khẩu. Nếu automatic login bỏ qua menu, tự tắt trong COSMIC Settings. Không restart `cosmic-greeter` trong phiên đang làm việc.

Nếu màn hình không dùng được, nhấn Ctrl+Alt+F3 và đăng nhập màn hình chữ. Đọc trước:

```bash
tail -n 120 "$HOME/.local/state/caelestia-pop-os/session.log"
```

Có thể xem log/rollback tại console. Không chạy thêm compositor chồng lên COSMIC hoặc giết toàn bộ tiến trình của người dùng. Nếu COSMIC đã bị gỡ bởi thao tác ngoài dự án, [hướng dẫn desktop System76](https://system76.com/support/desktop-environment/) có cách cài lại `pop-desktop`; xem mô phỏng APT và giữ greeter/driver trước khi sửa.

## Khôi phục cấu hình trước đó

Chạy trong repo bằng người dùng bình thường:

```bash
./setup.sh rollback --backup latest --dry-run
./setup.sh rollback --backup latest --yes
```

Đọc mã backup và manifest được chọn trước khi áp dụng. Giữ thư mục backup và repo. Deploy sao lưu các đường dẫn do dự án quản lý trước khi thay, gồm cấu hình Hyprland/shell/profile, wrapper người dùng, unit và tích hợp phiên nếu có ghi trong manifest. Manifest quyết định file nào được khôi phục; không đoán thêm các file ngoài đó.

Rollback **chỉ khôi phục cấu hình**. Gói APT, Qt/Wayland riêng, tool đã build và cache vẫn còn. Nó từ chối ghi đè file bạn đã sửa sau deploy; hãy giữ thay đổi và giải quyết xung đột rõ ràng, không ép bằng cách xóa file. Rollback thành công không tự đăng xuất và chưa xác nhận phiên cũ đã chạy. Tự lưu việc và đăng nhập lại khi sẵn sàng.

Các đường dẫn nên biết với XDG mặc định:

| Đường dẫn | Vai trò |
| --- | --- |
| `~/.config/hypr/hyprland.lua` | Cấu hình compositor chính |
| `~/.config/hypr/caelestia-windows.lua` | Trạng thái/thao tác cửa sổ chung |
| `~/.config/hypr/caelestia-shortcuts.lua` | Phím tắt và bảng đổi cửa sổ |
| `~/.config/hypr/hyprland-gui.lua` | Tích hợp thiết lập GUI tùy chọn |
| `~/.config/caelestia/shell.json`, `cli.json` | Tùy chọn shell và CLI |
| `~/.config/caelestia-pop-os/profile.json`, `profile.env` | Lựa chọn phiên đã sinh |
| `~/.local/bin/start-caelestia-session`, `start-caelestia-services` | Khởi động phiên theo người dùng |
| `~/.local/state/caelestia-pop-os/session.log` | Log khởi động |

## Cập nhật có kiểm tra

Trước hết quay về COSMIC hoặc kết thúc công việc trong Hyprland. Giữ revision cũ và mã backup. Ghi lại trạng thái repo:

```bash
git status --short
git rev-parse HEAD
git fetch --tags origin
```

Đọc release note và so sánh `pins.json` trước khi chọn bản/commit mới. Không ghi đè sửa đổi cục bộ hoặc mặc định nhánh `main` luôn ổn định. Nếu checkout sạch và cập nhật đúng nhánh, có thể dùng `git pull --ff-only`, đọc diff rồi mới cài.

```bash
./setup.sh preflight
./setup.sh plan
./setup.sh install --dry-run
```

Sau đó chạy `install --yes` với cùng tùy chọn/scale/cache mong muốn. Kiểm tra backup mới, chạy `doctor`, tự đăng nhập phiên mới rồi lặp lại [kiểm tra lần đầu](INSTALL.md#8-kiểm-tra-lần-đăng-nhập-đầu). Trình cài không phải hệ thống tự nâng ABI liên tục: Quickshell, plugin shell, Hyprland và headers phải tương thích. Đọc kỹ cập nhật APT làm đổi compositor đã ghim; không nạp plugin build cho ABI Hyprland khác.

Build dở thường có thể chạy lại cùng cache sau khi sửa nguyên nhân. Script kiểm tra pin/receipt. Giữ thay đổi trong source; không `git reset --hard` cache chưa rõ nguồn gốc chỉ để qua kiểm tra.

## Dọn phần build

```bash
./setup.sh clean-cache --dry-run
./setup.sh clean-cache --yes
```

Nếu dùng cache riêng, truyền lại `--cache-dir PATH`. Lệnh chỉ dọn thư mục build của trình cài bên trong cache riêng; giữ source/download/receipt và file đã cài. Đọc đúng đích được in trước khi chạy thật. Không thay bằng `rm -rf ~/.cache`, không dọn khi đang build.

## Gỡ tích hợp desktop này

Không có lệnh `uninstall` xóa mọi thứ tự động. Thứ tự an toàn:

1. Đăng xuất Hyprland, xác nhận COSMIC hoạt động.
2. Xem trước rồi rollback cấu hình theo backup thích hợp. Giữ file đã sửa sau cài cho đến khi lưu/gộp xong.
3. Nếu muốn bỏ hẳn tên phiên đăng nhập, xem hai file:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
cat /usr/local/bin/caelestia-pop-os-session
```

Nếu rollback đã gỡ chúng thì không cần xóa nữa. Nếu chúng vẫn là bản của dự án **và không người dùng nào khác còn cần phiên này**, chỉ gỡ đúng hai file tích hợp:

```bash
sudo rm -- /usr/share/wayland-sessions/hyprland-caelestia.desktop
sudo rm -- /usr/local/bin/caelestia-pop-os-session
```

Không xóa file phiên Wayland khác. Hai đường dẫn hệ thống này dùng chung giữa mọi user. File người dùng nên khôi phục/gỡ theo backup đã ghi; không xóa cả `~/.config/hypr` hoặc `~/.config/caelestia`.

Gói APT dùng chung và tool `/usr/local` được giữ có chủ ý. Nếu muốn gỡ sâu hơn, xem dependency, manifest build trong `builds/*/install_manifest.txt` của cache, receipt và kế hoạch gói. Manifest có thể chứa file phần mềm khác đang dùng; dùng để xem xét thủ công, không đưa thẳng vào lệnh xóa hàng loạt. `/opt/qt6`, `/opt/caelestia-wayland`, môi trường Python, font và tool có thể dùng chung hoặc đã sửa về sau; chỉ gỡ khi xác minh quyền sở hữu và không còn phần mềm nào cần.

Có thể xóa checkout nguồn sau khi giữ thông tin phiên bản và backup. Không xóa bản duy nhất của sửa đổi cá nhân, credential hoặc video của bạn khi dọn desktop.
