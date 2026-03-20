<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>后台登录</title>
    <style>
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            font-family: "PingFang SC", "Noto Serif SC", sans-serif;
            background:
                radial-gradient(circle at top right, rgba(180, 98, 41, 0.28), transparent 30%),
                linear-gradient(180deg, #efe4d2 0%, #f7f2e9 100%);
            color: #2d2518;
        }
        .card {
            width: min(420px, calc(100vw - 32px));
            background: rgba(255, 251, 243, 0.96);
            border: 1px solid rgba(111, 78, 46, 0.16);
            border-radius: 18px;
            box-shadow: 0 24px 50px rgba(103, 74, 41, 0.14);
            padding: 28px;
        }
        h1 { margin: 0 0 8px; font-size: 28px; }
        p { margin: 0 0 22px; color: #786b58; font-size: 14px; }
        label { display: block; font-size: 13px; color: #786b58; margin-bottom: 6px; }
        input {
            width: 100%;
            height: 44px;
            border: 1px solid #d9ccb8;
            border-radius: 10px;
            padding: 0 12px;
            font-size: 14px;
            background: #fffdfa;
            margin-bottom: 16px;
            box-sizing: border-box;
        }
        button {
            width: 100%;
            height: 46px;
            border: 0;
            border-radius: 10px;
            background: #8a4f1d;
            color: #fff8ef;
            font-size: 15px;
            cursor: pointer;
        }
        .error {
            background: rgba(160, 61, 47, 0.12);
            color: #a03d2f;
            border-radius: 10px;
            padding: 12px 14px;
            margin-bottom: 16px;
            font-size: 14px;
        }
        .hint {
            margin-top: 14px;
            color: #8c7d67;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>后台登录</h1>
        <p>使用最小后台管理员账号进入配置与查询页。</p>

        @if($errors->any())
            <div class="error">{{ $errors->first() }}</div>
        @endif

        <form method="POST" action="{{ route('admin.login.submit') }}">
            @csrf
            <label for="username">账号</label>
            <input id="username" name="username" type="text" value="{{ old('username') }}" required>

            <label for="password">密码</label>
            <input id="password" name="password" type="password" required>

            <button type="submit">进入后台</button>
        </form>
        <div class="hint">默认调试账号会由 Seeder 写入，可在本地环境中按需更换。</div>
    </div>
</body>
</html>
