# Cách dùng và phím tắt

[English](../en/USAGE.md) · [Cài đặt](INSTALL.md) · [Khắc phục lỗi](TROUBLESHOOTING.md)

**Win / Super** là phím logo Windows. Workspace mới mặc định xếp ô (tiling); mỗi workspace nhớ lựa chọn Float/Tiling riêng. Click để chọn cửa sổ; rê chuột qua app khác không tự đổi focus. Đổi app/workspace không tự kéo con trỏ đi nơi khác.

## Bảng phím tắt

| Phím | Tác dụng |
| --- | --- |
| Win+Enter hoặc Win+T | Mở terminal Foot |
| Win+D | Mở launcher tìm ứng dụng |
| Win+E | Mở COSMIC Files |
| Win+B | Mở trình duyệt được cấu hình/mặc định |
| Alt+Tab | Giữ Alt để xem bảng chọn cửa sổ; Tab chọn tiếp, nhả Alt để chốt |
| Alt+Shift+Tab | Chọn theo chiều ngược |
| Alt+Esc khi đang chọn | Hủy, không đổi cửa sổ |
| Alt+F4 hoặc Win+Q | Đóng cửa sổ đang chọn |
| Alt+F10 | Phóng to/khôi phục, vẫn chừa chỗ cho shell |
| Win+F | Bật/tắt toàn màn hình |
| Win+H | Thu nhỏ cửa sổ đang chọn |
| Win+Shift+H | Mở lại một cửa sổ thu nhỏ vào workspace hiện tại |
| Win+M | Thu nhỏ các cửa sổ không ghim của workspace hiện tại |
| Win+Shift+M | Mở lại nhóm vừa thu nhỏ bằng Win+M |
| Win+V | Chuyển một cửa sổ giữa dạng nổi và xếp ô |
| Win+Shift+V | Mở lịch sử clipboard |
| Win+các phím mũi tên | Chọn cửa sổ theo hướng tương ứng |
| Win+kéo chuột trái | Di chuyển cửa sổ |
| Win+kéo chuột phải | Đổi kích thước cửa sổ |
| Win+1…9, 0 | Chuyển workspace; 0 là workspace 10 |
| Win+Shift+1…9, 0 | Chuyển cửa sổ sang workspace tương ứng |
| Win+N | Mở/đóng sidebar thông báo |
| Win+L | Khóa màn hình; cần thử mở khóa bằng mật khẩu trước |
| Ctrl+Shift+Esc | Mở btop để xem tài nguyên/tiến trình |
| Print Screen | Chụp toàn màn hình vào clipboard; bấm Save trong thông báo để lưu |
| Win+Shift+S | Chọn vùng chụp; Esc hủy |
| Win+Ctrl+Shift+Q | Đăng xuất Hyprland; lưu công việc trước |

Không thêm Win+R trùng launcher. Ctrl+Tab/Ctrl+Shift+Tab vẫn do từng app dùng để chuyển tab. Phím âm lượng/độ sáng laptop được gán khi thiết bị có hỗ trợ; vuốt ngang ba ngón để đổi workspace phụ thuộc touchpad.

## Cửa sổ và bố cục

Thanh tiêu đề có nút thu nhỏ, phóng to/khôi phục và đóng. Nhấp đúp thanh tiêu đề để phóng to/khôi phục. Phóng to khác toàn màn hình: khi toàn màn hình che thanh tiêu đề/sidebar, dùng Win+F để thoát. Các cửa sổ nổi giữ trạng thái phóng to riêng khi đổi app. Plugin native đồng bộ thao tác cửa sổ từ chính ứng dụng.

Nút **Float/Tiling** trên sidebar chỉ đổi workspace đang đứng. Workspace mới mặc định tiling; mỗi workspace lưu lựa chọn riêng qua các lần đăng nhập. Nút tự cập nhật khi đổi workspace. App mở mới hoặc chuyển sang workspace khác theo chế độ của workspace đích; cửa sổ ghim và special workspace không bị đổi. Win+V vẫn chỉ đổi một cửa sổ. Khi thử xếp ô, giữ một terminal mở để dễ xử lý bố cục không như ý.

Thanh app đang chạy có một biểu tượng cho mỗi cửa sổ, kể cả ở workspace khác hoặc đã thu nhỏ. Rê để xem tên; cuộn nếu danh sách dài. Bấm icon đang chọn để thu nhỏ, bấm icon khác để chuyển sang, bấm icon đã thu nhỏ để mở tại workspace hiện tại. Dấu cạnh dài chỉ cửa sổ đang chọn; icon mờ chỉ cửa sổ thu nhỏ. Win+Shift+M chỉ mở lại nhóm đã lưu bởi Win+M, không kéo theo các cửa sổ đã thu nhỏ từ trước.

Hai vùng chỉnh âm lượng/độ sáng bằng con lăn trên toàn thanh bar được tắt mặc định. Lăn trên danh sách app chỉ cuộn danh sách khi dài; lăn trên vùng workspace vẫn chuyển workspace. Dùng phím âm lượng/độ sáng hoặc các điều khiển tương ứng để chỉnh.

## Bảng Alt+Tab có ảnh xem trước

Giữ Alt, bấm Tab để hiện bảng chọn. Danh sách gồm cửa sổ của workspace hiện tại và cửa sổ thu nhỏ, ưu tiên cửa sổ vừa dùng. Tab đi tiếp, Shift+Tab đi ngược; nhả Alt mới chuyển thật. Có thể click thẻ để chọn. Giữ Alt rồi Esc hoặc click ra ngoài để hủy. Cửa sổ thu nhỏ chỉ được mở lại khi chốt. Nếu ứng dụng không cung cấp ảnh preview, thẻ hiện icon. Chuột giữ nguyên vị trí.

## Launcher và clipboard

Win+D mở tìm ứng dụng. Launcher mở bằng hover có thể đóng khi chuột rời vùng trước khi bạn gõ; khi đã nhập tìm kiếm thì nó giữ thao tác nhập. Dùng Win+D nếu không thích mở bằng hover.

Win+Shift+V mở lịch sử clipboard. Chọn mục, Enter rồi Ctrl+V trong app đích. Watcher văn bản/ảnh chỉ chạy trong phiên; nội dung copy trước khi watcher khởi động có thể không xuất hiện. Clipboard có thể chứa dữ liệu riêng tư; kiểm tra trước khi chụp màn hình/chia sẻ. Nếu chủ động muốn xóa toàn bộ lịch sử, dùng `cliphist wipe`.

## Chụp và quay màn hình

Print Screen chụp màn hình; Win+Shift+S chọn vùng. Esc hủy khoanh vùng. Swappy cung cấp chỉnh sửa/ghi chú ảnh trong luồng chụp có gọi trình chỉnh sửa.

Mở **Utilities → Screen recorder / Record screen**. Chọn toàn màn hình hoặc một vùng, có/không âm thanh. Kéo chuột để khoanh vùng. Bấm **Stop**, chờ thông báo đã lưu. File nằm tại `~/Videos/Recordings`. Âm thanh lấy từ **monitor của đầu ra loa**, mã hóa AAC; không tự bật micro. Chỉ chạy một phiên quay. Nút Pause bị vô hiệu vì backend wf-recorder không hỗ trợ tạm dừng.

Có thể dùng CLI:

```bash
caelestia record
caelestia record -s
caelestia record -r
```

Chọn một lệnh bắt đầu phù hợp, sau đó gọi `caelestia record` lần nữa để dừng. `-s` bật âm thanh, `-r` chọn vùng. Xem `caelestia record --help` để kết hợp tùy chọn. Thử đoạn ngắn trước khi quay việc quan trọng, nhất là NVENC; tên encoder không bảo đảm GPU hỗ trợ.

## Tiếng Việt và công cụ tùy chọn

Khi cài `--vietnamese`, phiên khởi động Fcitx5 và chọn Unikey. Mở Fcitx5 Configuration để xem engine và thiết lập Telex. Ví dụ thường dùng: `tieengs Vieetj` → `tiếng Việt`; cách xử lý cụ thể theo tùy chọn Unikey. Xem phím bật/tắt trong cấu hình của bạn thay vì mặc định mọi máy dùng cùng phím.

HyprMod là giao diện thiết lập tùy chọn, không thay trình cài hoặc cập nhật hệ điều hành. Đọc lại thay đổi màn hình/scale trước khi áp dụng; giữ profile và backup. Trình duyệt hiện tại vẫn dùng làm mặc định trừ khi bạn tự chọn app khác.

AI Usage chỉ hiện một nhà cung cấp bạn chọn. Rê chuột vào widget, bấm tên nhà cung cấp, tìm và chọn mục khác. Lựa chọn được nhớ sau khi đăng nhập lại; backend chỉ cập nhật quota/số dư của mục đó. Kết nối tài khoản cục bộ rồi Refresh; số liệu thiếu sẽ hiện Unknown. Xem [cách kết nối provider](../AI-USAGE.md).

## Khóa màn hình, idle và nguồn điện

Ban đầu tắt tự động idle và xác thực vân tay. Hãy lưu công việc, thử Win+L và mở khóa mật khẩu/PAM thủ công, rồi mới tự bật auto-lock, tắt màn hình hoặc suspend. Sleep/wake cần thử trên phần cứng của bạn.

Pop!_OS giữ `system76-power`. Không hứa nút power profile của upstream hoạt động vì dự án không cài `power-profiles-daemon` xung đột. Xem các thao tác hỗ trợ mà không đổi profile:

```bash
system76-power help
system76-power profile --help
```

Đọc help của phiên bản đã cài trước khi chủ động đổi profile. Chế độ GPU, profile điện CPU, độ sáng và suspend là các điều khiển khác nhau.

## Cava trong terminal và HyprMod

Chạy `cava` hoặc `terminalcava` trong Foot khi nhạc đang phát qua đầu ra loa đang chọn. Template màu của CLI dùng output `noncurses` và input monitor PulseAudio; nó độc lập với visualizer nền desktop. Lần áp dụng wallpaper/scheme đầu tiên sẽ tạo config terminal. Nếu màn hình đen, xác nhận nghe được nhạc, xem `pactl get-default-sink`, kiểm tra `~/.config/cava/config`: output có `method = noncurses`, input có `method = pulse` và `source = auto`. Mute hoặc âm lượng quá nhỏ có thể không còn tín hiệu hữu ích.

Nếu đã cài, mở `hyprmod` từ launcher hoặc terminal. Chủ động xem rồi lưu thay đổi màn hình/scale vào `hyprland-gui.lua`. Trình cài không tự mở GUI hoặc đổi GPU mode.

## Chữ trình duyệt sắc nét khi dùng scale lẻ

Ưu tiên Wayland native nếu trình duyệt hỗ trợ. Với Brave, xem `brave://version`, `brave://gpu`, thử mở riêng với `--ozone-platform=wayland`. Phiên Brave đang chạy có thể bỏ qua cờ mới. Bản Flatpak có thể lưu cờ tại `~/.var/app/com.brave.Browser/config/brave-flags.conf`; giữ cờ cũ và chỉ thêm `--ozone-platform=wayland` nếu cần. Tự lưu biểu mẫu/công việc trước khi đóng và mở lại trình duyệt. Installer giữ trình duyệt mặc định, không ghi đè profile.
