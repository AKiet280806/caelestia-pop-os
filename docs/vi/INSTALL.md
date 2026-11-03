# Cài từ desktop COSMIC đến Hyprland + Caelestia

[English](../en/INSTALL.md) · [Trang chính](../../README.md) · [Hướng dẫn từng thành phần](MANUAL.md)

Hướng dẫn bắt đầu khi bạn đang dùng **Pop!_OS 24.04 amd64 với desktop COSMIC mặc định**. Dự án thêm một phiên Hyprland + Caelestia để chọn lúc đăng nhập, đồng thời giữ COSMIC làm đường quay về.

**Bản 0.1.0 còn là pre-release.** Desktop tùy biến đã được chạy và kiểm tra trên một máy thật; toàn bộ quy trình cài trên máy Pop!_OS mới sạch **chưa được kiểm thử hoàn chỉnh**. Kiểm tra tĩnh hoặc chạy thử trình cài với thư mục home tạm không thay thế việc kiểm thử đó. Hãy sao lưu tài liệu quan trọng và giữ COSMIC.

## 1. Mở Terminal và kiểm tra máy

Trong COSMIC, mở danh sách ứng dụng, tìm **Terminal**. Dán từng khối lệnh, chờ chạy xong rồi đọc kết quả. Khi `sudo` hỏi mật khẩu, màn hình không hiện ký tự bạn gõ; đây là bình thường.

```bash
cat /etc/os-release
dpkg --print-architecture
uname -r
free -h
df -h "$HOME" /opt /tmp
lspci -nnk | sed -n '/VGA\|3D\|Display/,+3p'
ls -l /dev/dri/by-path/
```

Cần thấy Pop!_OS 24.04 và kiến trúc `amd64`. `lspci` cho biết GPU và driver kernel; `/dev/dri/by-path/` giúp đối chiếu thiết bị đồ họa. Giữ kết quả để chẩn đoán khi cần. Thiếu một lệnh xem thông tin chưa đồng nghĩa driver hỏng.

Nếu dùng driver NVIDIA độc quyền, kiểm tra thêm:

```bash
nvidia-smi
sudo cat /sys/module/nvidia_drm/parameters/modeset
sudo system76-power graphics
```

`nvidia-smi` phải nhận GPU/driver; DRM modeset cần hiện `Y`. Nếu không đạt, xử lý driver theo hướng dẫn Pop!_OS/System76 trước. Không chép số `/dev/dri/card*` của máy khác hoặc thay driver hệ thống chỉ để giống máy đã thử. Lệnh `system76-power graphics` ở trên chỉ hỏi chế độ hiện tại. Đọc [hướng dẫn graphics switching của System76](https://support.system76.com/support/graphics-switch-pop/) trước khi chủ động đổi chế độ.

Máy quan sát được dùng Intel + RTX 4050, driver 595.104.02, chế độ NVIDIA, chỉ màn hình trong máy. Đây là phạm vi đã thử, không phải yêu cầu ép mọi laptop sang NVIDIA. GPU khác, hybrid/integrated, nhiều màn hình và suspend/resume cần được kiểm tra riêng.

## 2. Chuẩn bị dung lượng và hệ thống

Dự trù khoảng **8 GiB tải xuống/biên dịch**, **4 GiB runtime đã cài**, cộng **8 GiB chỗ trống dự phòng**. Nếu cùng một phân vùng, kiểm tra mặc định cần khoảng **20 GiB trống**. Nếu cache, `/opt` và home khác phân vùng, từng phân vùng phải đủ chỗ cho phần tương ứng. Đây là ước lượng, không phải giới hạn cứng cho mọi bản upstream.

Mặc định biên dịch bằng **2 job**. Máy ít RAM nên dùng `--jobs 1`. Đừng tăng job chỉ vì CPU có nhiều luồng. Hoàn tất cập nhật hệ điều hành bằng trình cập nhật COSMIC trước; nếu cần khởi động lại, hãy tự lưu công việc và khởi động lại trước khi cài desktop.

## 3. Tải toàn bộ mã nguồn

```bash
sudo apt update
sudo apt install --no-remove git
mkdir -p "$HOME/Projects"
cd "$HOME/Projects"
git clone https://github.com/AKiet280806/caelestia-pop-os.git
cd caelestia-pop-os
```

Giữ thư mục này để cập nhật và khôi phục. Các lệnh sau được chạy **bên trong thư mục repo**. Có thể đọc `setup.sh`, `installer/` và [hướng dẫn thủ công](MANUAL.md) để biết chương trình làm gì. Chạy bằng người dùng bình thường, **không chạy `sudo ./setup.sh`**; trình cài tự yêu cầu `sudo` tại bước hệ thống cần quyền.

## 4. Xem trước trước khi cài

```bash
./setup.sh preflight
./setup.sh plan
./setup.sh install --dry-run
```

Đọc kết quả và xử lý lỗi phiên bản, APT, dung lượng trước. Hyprland được lấy từ PPA bên thứ ba **`ppa:cppiber/hyprland`**, mục tiêu Hyprland 0.57.0 với headers khớp phiên bản, gồm bản gói `0.57.0-1ppa3`. Không mặc định mọi bản tương lai trong PPA đều tương thích plugin.

Các thao tác APT của dự án phải từ chối gỡ gói. Nếu APT đòi bỏ `pop-desktop`, `cosmic-greeter`, `system76-power` hoặc driver, dừng lại và kiểm tra xung đột. `--dry-run` chỉ xem kế hoạch; chưa chứng minh tải xuống, biên dịch hay GPU hoạt động.

Để lấy báo cáo dạng JSON:

```bash
./setup.sh preflight --json
./setup.sh plan --json
```

## 5. Chọn tùy chọn

| Tùy chọn | Ý nghĩa |
| --- | --- |
| `--scale 1.0` | Mặc định; chọn scale phù hợp màn hình của bạn |
| `--scale 1.5` | Mức đã thử với màn 14 inch 2560×1600 |
| `--vietnamese` | Cài/cấu hình Fcitx5 + Unikey để gõ tiếng Việt Telex |
| `--with-hyprmod` | Thêm giao diện thiết lập HyprMod 0.5 tùy chọn |
| `--with-codex` | Thêm widget hạn mức tài khoản Codex tùy chọn |
| `--encoder libx264` | Quay H.264 bằng CPU, lựa chọn mặc định dễ tương thích |
| `--encoder auto` | Chọn dựa trên encoder khả dụng; cần đọc kết quả |
| `--encoder h264_nvenc` | Chọn NVIDIA rõ ràng sau khi kiểm tra GPU và FFmpeg |
| `--jobs 2` | Số job biên dịch; dùng 1 nếu RAM hạn chế |
| `--reserve-gib 8` | Giữ thêm số GiB trống ngoài nhu cầu cài dự kiến |
| `--cache-dir PATH` | Đặt cache/build trên phân vùng còn đủ chỗ |

Cache phải là thư mục riêng của dự án và người dùng của bạn có quyền ghi. Dùng lại cùng đường dẫn khi chạy tiếp các bước; không trỏ thẳng cache vào home. Không có quy tắc mọi máy đều dùng scale 167%.

Nếu muốn dùng NVIDIA để quay:

```bash
nvidia-smi
ffmpeg -hide_banner -encoders | rg 'libx264|h264_nvenc'
```

Tên encoder xuất hiện chưa bảo đảm GPU mã hóa được. Nếu chưa chắc, dùng `libx264` rồi thử video ngắn trước.

## 6. Chạy trình cài

Cài cơ bản:

```bash
./setup.sh install --yes
```

Ví dụ có bộ gõ tiếng Việt và giao diện HyprMod:

```bash
./setup.sh install --yes --scale 1.5 --vietnamese --with-hyprmod --encoder libx264 --jobs 2 --reserve-gib 8
```

Chỉ thêm tùy chọn bạn cần. Trình cài lần lượt cài gói, biên dịch runtime riêng và công cụ, biên dịch plugin đúng phiên bản, sao lưu cấu hình bị tác động rồi triển khai phiên đăng nhập. Giữ Terminal mở; bước Qt có thể lâu. Lưu lại thông tin backup và đầu ra cuối cùng.

Trình cài không tự đăng xuất, không tự reboot, không đổi display manager, không gỡ COSMIC, không cài `power-profiles-daemon`, không thay Python/Wayland toàn hệ thống.

Có thể tách các bước để kiểm tra; bước sau phụ thuộc bước trước:

```bash
./setup.sh packages --yes
./setup.sh runtime --yes
./setup.sh plugins --yes
./setup.sh deploy --yes
./setup.sh doctor
```

Khi chạy tách, truyền cùng các tùy chọn đã chọn vào từng bước. Không bỏ qua bước lỗi rồi đăng nhập desktop chưa hoàn chỉnh. [Hướng dẫn thủ công](MANUAL.md) giải thích thứ tự dependency và lệnh build.

## 7. Chọn phiên ở COSMIC Greeter

1. Lưu công việc, đóng ứng dụng bình thường. Tự chọn **Log Out / Đăng xuất** trong COSMIC.
2. Tại **COSMIC Greeter**, chọn người dùng nếu cần.
3. Mở **menu chọn phiên** trong vùng người dùng/phiên/trạng thái. Mã nguồn greeter hiện dùng biểu tượng menu ứng dụng (`application-menu-symbolic`); vị trí/giao diện có thể thay đổi theo phiên bản. Đừng tìm bánh răng GDM theo ảnh Ubuntu cũ.
4. Chọn **Hyprland (Caelestia Pop!_OS)**.
5. Nhập mật khẩu và đăng nhập.

Tham khảo [mã nguồn nút chọn phiên COSMIC Greeter](https://github.com/pop-os/cosmic-greeter/blob/master/src/greeter.rs). Nếu máy đăng nhập tự động và bỏ qua màn chọn phiên, vào COSMIC Settings tắt automatic login, lưu công việc rồi đăng xuất lại. Không restart dịch vụ greeter khi đang làm việc.

Không thấy mục Hyprland? Quay về Terminal trong COSMIC để xem:

```bash
cat /usr/share/wayland-sessions/hyprland-caelestia.desktop
command -v Hyprland
./setup.sh doctor
```

Đích `Exec=` trong file phiên phải tồn tại và thực thi được. Xem [khắc phục lỗi phiên](TROUBLESHOOTING.md#không-vào-được-phiên) trước khi thay display manager.

## 8. Kiểm tra lần đăng nhập đầu

Nhấn **Win+Enter** để mở Foot. Win/Super là phím có logo Windows.

```bash
./setup.sh doctor
hyprctl version
hyprctl monitors
systemctl --user status caelestia-shell.service --no-pager
```

Nếu Terminal đang ở home, `cd` về thư mục repo trước khi gọi `setup.sh`. Dùng Win+D mở ứng dụng; thử Alt+Tab, thu nhỏ/phóng to/đóng, âm lượng, độ sáng, chụp hình và video ngắn. Thanh app đang chạy hiển thị cả cửa sổ thu nhỏ. Đọc [cách dùng và phím tắt](USAGE.md).

Nếu bật tiếng Việt, mở **Fcitx5 Configuration**, thêm/chọn **Unikey**, chọn Telex phù hợp rồi thử trong ô nhập văn bản. Một số app Flatpak cần hỗ trợ bộ gõ riêng; không sửa một app bằng cách xuất đường dẫn Qt riêng ra toàn COSMIC.

Widget Codex tùy chọn đọc hạn mức Codex khả dụng từ phiên Codex cục bộ do chính bạn đăng nhập. Đây không phải số tin nhắn ChatGPT chat thông thường còn lại. Không chép thông tin đăng nhập vào repo. Xem liên kết cài/đăng nhập chính thức ở [phần công cụ tùy chọn](MANUAL.md#công-cụ-tùy-chọn).

## 9. Thử đường quay về COSMIC

Lưu công việc, nhấn Win+Ctrl+Shift+Q để đăng xuất Hyprland rồi chọn **COSMIC** trong cùng menu phiên. Nếu desktop không dùng được, nhấn **Ctrl+Alt+F3**, đăng nhập tại màn hình chữ và đọc log:

```bash
tail -n 100 "$HOME/.local/state/caelestia-pop-os/session.log"
```

Không vội xóa cấu hình hoặc purge gói để chữa màn hình đen. [Khôi phục và bảo trì](MAINTENANCE.md) hướng dẫn rollback cấu hình và gỡ riêng tích hợp của dự án.
