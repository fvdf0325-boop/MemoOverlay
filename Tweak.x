#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <pwd.h>

#define MEMO_PATH @"/var/jb/var/mobile/Documents/overlay_memo.txt"

static UIWindow *_overlayWindow = nil;
static UIWindow *_toggleBtnWindow = nil;
static UIWindow *_processWindow = nil;
static UITextView *_textView = nil;
static BOOL _isVisible = NO;
static BOOL _isProcessVisible = NO;

// ─── 실행 중인 프로세스 목록 가져오기 ─────────────
static NSArray<NSDictionary *> *getRunningProcesses() {
    NSMutableArray *list = [NSMutableArray array];

    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size = 0;
    sysctl(mib, 4, NULL, &size, NULL, 0);

    struct kinfo_proc *procs = malloc(size);
    if (sysctl(mib, 4, procs, &size, NULL, 0) == 0) {
        int count = (int)(size / sizeof(struct kinfo_proc));
        for (int i = 0; i < count; i++) {
            NSString *name = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
            int pid = procs[i].kp_proc.p_pid;
            if (name.length > 0 && pid > 0) {
                [list addObject:@{@"name": name, @"pid": @(pid)}];
            }
        }
    }
    free(procs);

    // 이름순 정렬
    [list sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"] options:NSCaseInsensitiveSearch];
    }];

    return list;
}

// ─── 저장/불러오기 ────────────────────────────────
static void saveMemo() {
    [_textView.text writeToFile:MEMO_PATH atomically:YES
                       encoding:NSUTF8StringEncoding error:nil];
}

static NSString *loadMemo() {
    NSString *s = [NSString stringWithContentsOfFile:MEMO_PATH
                                            encoding:NSUTF8StringEncoding error:nil];
    return s ?: @"";
}

// ─── 프로세스 선택 뷰컨 ──────────────────────────
@interface ProcessListVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray<NSDictionary *> *processes;
@property (nonatomic, strong) NSArray<NSDictionary *> *filtered;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation ProcessListVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.1 alpha:0.96];
    self.view.layer.cornerRadius = 14;

    // 타이틀바
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,44)];
    bar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12,0,200,44)];
    title.text = @" 프로세스 목록";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:13];
    [bar addSubview:title];

    // 새로고침 버튼
    UIButton *refreshBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-80,4,36,36)];
    [refreshBtn setTitle:@"↺" forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:20];
    [refreshBtn setTitleColor:[UIColor colorWithWhite:1 alpha:0.7] forState:UIControlStateNormal];
    [refreshBtn addTarget:self action:@selector(refresh) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:refreshBtn];

    // 닫기 버튼
    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-40,4,36,36)];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1 alpha:0.6] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeBtn];

    [self.view addSubview:bar];

    // 검색바
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,44,self.view.bounds.size.width,44)];
    self.searchBar.placeholder = @"프로세스 검색...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.backgroundImage = [UIImage new];
    self.searchBar.delegate = (id)self;
    [self.view addSubview:self.searchBar];

    // 테이블뷰
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0,88,
        self.view.bounds.size.width,
        self.view.bounds.size.height-88)
        style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.1];
    [self.view addSubview:self.tableView];

    [self refresh];
}

- (void)refresh {
    self.processes = getRunningProcesses();
    self.filtered = self.processes;
    [self.tableView reloadData];
}

- (void)close {
    _isProcessVisible = NO;
    _processWindow.hidden = YES;
}

// UISearchBar delegate
- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    if (text.length == 0) {
        self.filtered = self.processes;
    } else {
        self.filtered = [self.processes filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", text]];
    }
    [self.tableView reloadData];
}

// UITableView
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return self.filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:1 alpha:0.4];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
        cell.selectedBackgroundView = ({
            UIView *v = [[UIView alloc] init];
            v.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
            v;
        });
    }
    NSDictionary *proc = self.filtered[ip.row];
    cell.textLabel.text = proc[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"PID: %@", proc[@"pid"]];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *proc = self.filtered[ip.row];
    NSString *insert = [NSString stringWithFormat:@"[%@(PID:%@)] ", proc[@"name"], proc[@"pid"]];

    // 메모 텍스트뷰에 삽입
    if (_textView) {
        NSRange sel = _textView.selectedRange;
        NSMutableString *text = [_textView.text mutableCopy];
        [text insertString:insert atIndex:sel.location];
        _textView.text = text;
        _textView.selectedRange = NSMakeRange(sel.location + insert.length, 0);
        saveMemo();
    }

    // 메모창 열기
    if (!_isVisible) {
        _isVisible = YES;
        _overlayWindow.hidden = NO;
        [_overlayWindow makeKeyAndVisible];
    }

    [self close];
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return 48;
}

@end

// ─── 메모 뷰컨 ───────────────────────────────────
@interface MemoVC : UIViewController <UITextViewDelegate>
@end

@implementation MemoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.92];
    self.view.layer.cornerRadius = 14;
    self.view.layer.borderWidth = 0.5;
    self.view.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;

    // 타이틀바
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,36)];
    bar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12,0,120,36)];
    title.text = @" 메모";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:13];
    [bar addSubview:title];

    // 프로세스 버튼
    UIButton *procBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-72,0,36,36)];
    [procBtn setTitle:@"" forState:UIControlStateNormal];
    procBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [procBtn addTarget:self action:@selector(showProcessList) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:procBtn];

    // 닫기 버튼
    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-36,0,36,36)];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1 alpha:0.6] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeBtn];

    [self.view addSubview:bar];

    // 텍스트뷰
    _textView = [[UITextView alloc] initWithFrame:CGRectMake(8,40,
        self.view.bounds.size.width-16,
        self.view.bounds.size.height-48)];
    _textView.backgroundColor = [UIColor clearColor];
    _textView.textColor = [UIColor colorWithWhite:0.95 alpha:1];
    _textView.font = [UIFont systemFontOfSize:14];
    _textView.text = loadMemo();
    _textView.delegate = self;
    _textView.keyboardAppearance = UIKeyboardAppearanceDark;
    [self.view addSubview:_textView];

    // 드래그
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPan:)];
    [bar addGestureRecognizer:pan];
}

- (void)showProcessList {
    if (!_processWindow) {
        CGRect screen = [UIScreen mainScreen].bounds;
        _processWindow = [[UIWindow alloc]
            initWithFrame:CGRectMake(10, 80, screen.size.width-20, screen.size.height-160)];
        _processWindow.windowLevel = UIWindowLevelAlert + 200;
        _processWindow.backgroundColor = [UIColor clearColor];
        _processWindow.layer.cornerRadius = 14;
        _processWindow.clipsToBounds = YES;
        _processWindow.rootViewController = [[ProcessListVC alloc] init];
    } else {
        // 새로고침
        [(ProcessListVC *)_processWindow.rootViewController refresh];
    }
    _isProcessVisible = YES;
    _processWindow.hidden = NO;
    [_processWindow makeKeyAndVisible];
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:_overlayWindow];
    CGRect f = _overlayWindow.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    f.origin.x = MAX(0, MIN(f.origin.x + t.x, screen.size.width - f.size.width));
    f.origin.y = MAX(0, MIN(f.origin.y + t.y, screen.size.height - f.size.height));
    _overlayWindow.frame = f;
    [g setTranslation:CGPointZero inView:_overlayWindow];
}

- (void)textViewDidChange:(UITextView *)tv { saveMemo(); }

- (void)hide {
    _isVisible = NO;
    _overlayWindow.hidden = YES;
}

@end

// ─── 플로팅 토글 버튼 ─────────────────────────────
@interface ToggleBtnVC : UIViewController
@end

@implementation ToggleBtnVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0,0,44,44)];
    btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:0.9];
    btn.layer.cornerRadius = 22;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.4;
    btn.layer.shadowOffset = CGSizeMake(0,2);
    [btn setTitle:@"" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:22];
    [btn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPan:)];
    [btn addGestureRecognizer:pan];

    [self.view addSubview:btn];
}

- (void)toggle {
    if (!_overlayWindow) {
        _overlayWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20,120,300,220)];
        _overlayWindow.windowLevel = UIWindowLevelAlert + 50;
        _overlayWindow.backgroundColor = [UIColor clearColor];
        _overlayWindow.layer.cornerRadius = 14;
        _overlayWindow.clipsToBounds = YES;
        _overlayWindow.rootViewController = [[MemoVC alloc] init];
    }
    _isVisible = !_isVisible;
    _overlayWindow.hidden = !_isVisible;
    if (_isVisible) [_overlayWindow makeKeyAndVisible];
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:_toggleBtnWindow];
    CGRect f = _toggleBtnWindow.frame;
    CGRect screen = [UIScreen mainScreen].bounds;
    f.origin.x = MAX(0, MIN(f.origin.x + t.x, screen.size.width - 44));
    f.origin.y = MAX(60, MIN(f.origin.y + t.y, screen.size.height - 100));
    _toggleBtnWindow.frame = f;
    [g setTranslation:CGPointZero inView:_toggleBtnWindow];
}

@end

// ─── SpringBoard 훅 ───────────────────────────────
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        _toggleBtnWindow = [[UIWindow alloc]
            initWithFrame:CGRectMake(screen.size.width-54, 300, 44, 44)];
        _toggleBtnWindow.windowLevel = UIWindowLevelAlert + 100;
        _toggleBtnWindow.backgroundColor = [UIColor clearColor];
        _toggleBtnWindow.rootViewController = [[ToggleBtnVC alloc] init];
        _toggleBtnWindow.hidden = NO;
        [_toggleBtnWindow makeKeyAndVisible];
    });
}
%end

