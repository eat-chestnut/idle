@extends('admin.layouts.app')

@section('content')
    <div class="panel">
        <div class="actions" style="justify-content: space-between; margin-bottom: 18px;">
            <div>
                <strong>第一阶段后台运维工具</strong>
                <div class="hint">这里集中处理引用检查、奖励补发和最小安全修复，所有正式写入仍复用正式链路。</div>
            </div>
        </div>

        <div class="grid">
            <form method="POST" action="{{ route('admin.tools.reference-check') }}" class="panel" style="margin: 0;">
                @csrf
                <strong>配置引用检查</strong>
                <div class="hint" style="margin: 8px 0 14px;">用于禁用 / 删除前先看真实下游引用。</div>
                <div class="grid">
                    <div>
                        <label for="reference_resource">资源</label>
                        <select id="reference_resource" name="resource">
                            @foreach($config_resources as $value => $label)
                                <option value="{{ $value }}" @selected(old('resource', $reference_defaults['resource']) === $value)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div>
                        <label for="reference_record_key">记录主键</label>
                        <input id="reference_record_key" name="record_key" type="text" value="{{ old('record_key', $reference_defaults['record_key']) }}">
                    </div>
                </div>
                <div class="actions" style="margin-top: 16px;">
                    <button class="button secondary" type="submit">执行检查</button>
                </div>
            </form>

            <form method="POST" action="{{ route('admin.tools.reward-retry') }}" class="panel" style="margin: 0;">
                @csrf
                <strong>奖励补发</strong>
                <div class="hint" style="margin: 8px 0 14px;">优先使用 `reward_grant_id`；若按业务来源定位，请同时填写 `user_id + source_type + source_id`。</div>
                <div class="grid">
                    <div>
                        <label for="retry_reward_grant_id">reward_grant_id</label>
                        <input id="retry_reward_grant_id" name="reward_grant_id" type="number" min="1" value="{{ old('reward_grant_id') }}">
                    </div>
                    <div>
                        <label for="retry_user_id">user_id</label>
                        <input id="retry_user_id" name="user_id" type="number" min="1" value="{{ old('user_id') }}">
                    </div>
                    <div>
                        <label for="retry_source_type">source_type</label>
                        <select id="retry_source_type" name="source_type">
                            @foreach($reward_source_types as $value => $label)
                                <option value="{{ $value }}" @selected(old('source_type') === $value)>{{ $label }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div>
                        <label for="retry_source_id">source_id</label>
                        <input id="retry_source_id" name="source_id" type="text" value="{{ old('source_id') }}">
                    </div>
                </div>
                <div class="actions" style="margin-top: 16px;">
                    <button class="button secondary" type="submit">执行补发</button>
                </div>
            </form>

            <form method="POST" action="{{ route('admin.tools.repair-battle-context') }}" class="panel" style="margin: 0;">
                @csrf
                <strong>Battle Context 修复</strong>
                <div class="hint" style="margin: 8px 0 14px;">只修字段自相矛盾的最小安全场景，不提供任意改状态。</div>
                <div>
                    <label for="repair_battle_context_id">battle_context_id</label>
                    <input id="repair_battle_context_id" name="battle_context_id" type="text" value="{{ old('battle_context_id') }}">
                </div>
                <div class="actions" style="margin-top: 16px;">
                    <button class="button secondary" type="submit">执行修复</button>
                </div>
            </form>

            <form method="POST" action="{{ route('admin.tools.repair-reward-grant') }}" class="panel" style="margin: 0;">
                @csrf
                <strong>发奖记录修复</strong>
                <div class="hint" style="margin: 8px 0 14px;">只修 `reward_grants` 的明确安全矛盾字段，不直接改 `reward_grant_items`。</div>
                <div>
                    <label for="repair_reward_grant_id">reward_grant_id</label>
                    <input id="repair_reward_grant_id" name="reward_grant_id" type="number" min="1" value="{{ old('reward_grant_id') }}">
                </div>
                <div class="actions" style="margin-top: 16px;">
                    <button class="button secondary" type="submit">执行修复</button>
                </div>
            </form>
        </div>
    </div>

    @if($tool_result)
        <div class="panel">
            <strong>{{ $tool_result['title'] }}</strong>
            <div class="grid" style="margin: 14px 0;">
                @foreach($tool_result['summary'] ?? [] as $label => $value)
                    <div>
                        <label>{{ $label }}</label>
                        <div>{{ is_scalar($value) ? $value : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) }}</div>
                    </div>
                @endforeach
            </div>

            @if(isset($tool_result['payload']))
                <pre>{{ json_encode($tool_result['payload'], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) }}</pre>
            @endif
        </div>
    @endif
@endsection
