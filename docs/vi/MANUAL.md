# Cài từng thành phần, từ COSMIC

[Hướng dẫn cài chính](INSTALL.md) · [English](../en/MANUAL.md)

Bắt đầu trong COSMIC trên Pop!_OS 24.04 amd64, sau khi clone repo và đọc hướng dẫn chính. Chạy bằng người dùng thường; giữ COSMIC và driver của bản phân phối. Các bước dưới dùng cùng mã triển khai với lệnh `install`, giúp bạn hiểu hệ thống và chạy tiếp đúng bước khi gặp lỗi. Quy trình trên máy cài mới hoàn toàn vẫn chưa được kiểm thử trọn vẹn.

## 1. Kiểm tra điều kiện và danh sách gói

```bash
./setup.sh preflight --json
./setup.sh plan --json --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
```

Trường `packages` của kế hoạch là danh sách APT đầy đủ, được định nghĩa trong `installer/install.py`: GCC/G++ 14, CMake/Ninja/Meson/autotools, thư viện phát triển đồ họa/âm thanh/PAM, dependency để build plugin Hyprland, portal, terminal Foot, clipboard, chụp/quay màn hình, độ sáng và authentication agent. `--vietnamese` thêm Fcitx5, Unikey và frontend GTK/Qt.

Nếu NVIDIA modeset không đọc được do quyền, chạy `sudo -v` trong terminal rồi chạy lại preflight. Không tắt kiểm tra hoặc đổi driver để bỏ qua lỗi. Mặc định cần khoảng 20 GiB trống nếu cache và runtime cùng phân vùng, gồm 8 GiB dự phòng; biên dịch bằng hai job.

## 2. Cài dependency của hệ thống

```bash
./setup.sh packages --yes --vietnamese
```

Lệnh thêm PPA bên thứ ba `ppa:cppiber/hyprland`, cập nhật metadata, yêu cầu đúng bản Hyprland trong `pins.json`, mô phỏng toàn bộ giao dịch, từ chối gỡ gói rồi mới cài với `--no-remove`. Gói `hyprland` đã có headers; `hyprland-plugin-deps` cung cấp dependency phát triển bên ngoài. Không cần tìm gói `hyprland-dev` riêng. Không cài `power-profiles-daemon` thay cho `system76-power`.

## 3. Chọn cache riêng

Chạy các lệnh tiếp theo trong thư mục repo, giữ cùng biến môi trường ở mọi bước:

```bash
export CAELESTIA_CACHE_DIR="$HOME/.cache/caelestia-pop-os"
export CAELESTIA_JOBS=2
```

Cache gồm `sources/`, `builds/`, `downloads/`, `receipts/`, `logs/`. Script khóa cache để tránh hai tiến trình build cùng lúc. Source dùng commit đầy đủ và từ chối checkout có sửa đổi; artifact có hash sẽ được kiểm tra checksum. Không reset source hoặc xóa log để che lỗi.

## 4. Cài Qt và Python riêng

```bash
installer/runtime.sh toolchain
```

Bước này cài uv qua pipx riêng, Python 3.13 được quản lý riêng cho CLI và aqtinstall. aqt tải **SDK Qt 6.11.2 dạng binary** cùng imageformats/shadertools vào `/opt/qt6/6.11.2/gcc_64`; không biên dịch Qt hay thay Python hệ thống. Prefix Qt thiếu file/sai phiên bản sẽ bị từ chối để bạn xử lý rõ ràng trước khi chạy tiếp.

## 5. Build Wayland, libcava, Quickshell và module shell

Chạy lần lượt, dừng ở bước đầu tiên báo lỗi:

```bash
installer/runtime.sh wayland
installer/runtime.sh cava
installer/runtime.sh quickshell
installer/runtime.sh m3shapes
installer/runtime.sh shell
```

Wayland 1.26 nằm trong `/opt/caelestia-wayland`, không thay loader hay thư viện Wayland của COSMIC. Fork libcava cung cấp backend visualizer và Cava chạy terminal. Quickshell dùng cpptrace, Qt/Wayland đúng pin; M3Shapes và module C++ Caelestia vào `/usr/local/lib/qt6/qml`, helper vào `/usr/local/lib/caelestia`. CMake chỉ cài extras/plugin; cấu hình người dùng sẽ được sao lưu và triển khai riêng ở bước sau.

RPATH của binary/module trỏ đến runtime riêng, nên phiên không cần export `LD_LIBRARY_PATH` cho mọi ứng dụng. Khi chẩn đoán liên kết:

```bash
env -u LD_LIBRARY_PATH /usr/local/bin/qs --version
ldd /usr/local/bin/qs
```

## 6. Cài CLI, font và công cụ desktop

```bash
installer/runtime.sh cli
installer/runtime.sh fonts
installer/runtime.sh tools
```

CLI dùng môi trường Python 3.13 riêng. Script kiểm tra commit đã cài trước khi thay recorder và template Cava bằng mã trong `src/cli-overrides/`. Recorder dùng wf-recorder, H.264 và tùy chọn AAC từ loa/monitor của sink; `libx264` dùng CPU dễ tương thích, `h264_nvenc` cần NVIDIA encode hoạt động. Backend này chưa hỗ trợ pause.

Font gồm Rubik, Material Symbols Rounded, CaskaydiaCove Nerd Font cùng license và hash kiểm tra. Bước tools cài Dart Sass standalone và build Swappy, không cần nâng Node hệ thống. Grim/slurp, wl-clipboard/cliphist, brightnessctl, btop và portal đã nằm trong dependency APT.

## 7. Build plugin đúng ABI

```bash
./setup.sh plugins --yes
```

Script kiểm tra bản gói Hyprland, commit, hash header và pkg-config trước khi build hyprbars cùng native window actions. Plugin native giữ trạng thái maximize sau fullscreen và chuyển tiếp minimize từ ứng dụng. File được thay nguyên tử trong `~/.local/share/hypr/plugins/`; không ghi đè trực tiếp lên inode thư viện compositor đang dùng. Sai ABI phải xử lý bằng bộ source/header tương thích, không bỏ kiểm tra.

## 8. HyprMod và AI Usage tùy chọn

```bash
installer/runtime.sh hyprmod
```

HyprMod dùng Python 3.12 của bản phân phối trong môi trường riêng với GTK4/libadwaita. Nó chỉnh `hyprland-gui.lua`; module phím tắt được nạp sau để giữ chuột đứng yên khi đổi app. Bước cài không tự mở giao diện HyprMod.

Chạy `installer/runtime.sh aiusage`, rồi thêm `--with-ai-usage` khi deploy để có widget chung. Backend CodexBar được ghim phiên bản; chỉ một nhà cung cấp do bạn chọn trong popup được cập nhật. Codex giữ RPC chỉ đọc, provider khác dùng nguồn API/OAuth/web phù hợp. Xem [AI Usage](../AI-USAGE.md) để kết nối tài khoản và biết giới hạn trên Linux; không gửi prompt để thử quota.

## 9. Sao lưu và triển khai cấu hình

Nhắc lại các tùy chọn bạn đã chọn:

```bash
./setup.sh deploy --dry-run --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
./setup.sh deploy --yes --scale 1.5 --vietnamese --with-hyprmod --encoder libx264
./setup.sh doctor
```

Mỗi đích bị thay đều được backup và kiểm tra nội dung trước khi ghi. Script từ chối cấu hình chứa symlink; hãy giữ dotfiles hiện có và thực hiện migration có chủ đích. Cấu hình triển khai gồm toàn bộ shell, Lua, shell/CLI JSON, portal, helper, IME/AI Usage tùy chọn và user units. Ba file hệ thống là session entry, launcher do root sở hữu và `/etc/pam.d/quickshell` dùng các PAM include của Ubuntu.

Callback của phiên chỉ khởi chạy shell, clipboard watchers, authentication agent và integration đã chọn sau khi Hyprland chạy. Deploy không khởi chạy chúng bên trong COSMIC. Idle timeout và fingerprint ban đầu tắt; thử khóa/mở bằng mật khẩu khi đã có đường khôi phục trước khi bật tự khóa/sleep.

## 10. Đăng nhập và kiểm tra

Tự lưu công việc và đăng xuất. Trong menu chọn phiên của COSMIC Greeter, chọn **Hyprland (Caelestia Pop!_OS)** rồi nhập mật khẩu. Làm theo [hướng dẫn đăng nhập/kiểm tra](INSTALL.md), [phím tắt](USAGE.md), [khôi phục](MAINTENANCE.md). Build thành công hoặc doctor đạt chưa chứng minh GPU đăng nhập thành công trên máy mới.

`./setup.sh runtime --yes` chạy gộp các bước runtime theo thứ tự, có thể thêm tùy chọn cần thiết. `./setup.sh install --yes` chạy cả APT, runtime/plugin và deploy. Khi khôi phục lỗi, giữ cùng cache và tùy chọn đã chọn.

Xem [AI Usage](../AI-USAGE.md) để chọn một nhà cung cấp và cấu hình nguồn usage.
