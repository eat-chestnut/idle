@extends('admin.layouts.app')

@section('content')
    <div class="panel">
        <div class="actions" style="justify-content: space-between; margin-bottom: 18px;">
            <div class="hint">当前资源：{{ $page_title }}</div>
            <div class="actions">
                @if($reference_check_url)
                    <a class="button secondary" href="{{ $reference_check_url }}">查看引用检查</a>
                @endif
                <a class="button ghost" href="{{ $back_url }}">返回列表</a>
            </div>
        </div>

        <form method="POST" action="{{ $form_action }}">
            @csrf
            @if($form_method !== 'POST')
                @method($form_method)
            @endif

            <div class="grid">
                @foreach($fields as $field)
                    @if(($field['type'] ?? 'text') === 'checkbox')
                        <div class="checkbox-wrap">
                            <input id="field_{{ $field['name'] }}" name="{{ $field['name'] }}" type="checkbox" value="1" @checked((bool) $field['value'])>
                            <label for="field_{{ $field['name'] }}" style="margin: 0;">{{ $field['label'] }}</label>
                        </div>
                    @elseif(($field['type'] ?? 'text') === 'select')
                        <div>
                            <label for="field_{{ $field['name'] }}">{{ $field['label'] }}</label>
                            <select
                                id="field_{{ $field['name'] }}"
                                name="{{ $field['readonly'] ? '' : $field['name'] }}"
                                @disabled($field['readonly'])
                            >
                                @foreach($field['options_resolved'] as $optionValue => $optionLabel)
                                    <option value="{{ $optionValue }}" @selected((string) $field['value'] === (string) $optionValue)>{{ $optionLabel }}</option>
                                @endforeach
                            </select>
                            @if($field['readonly'])
                                <input type="hidden" name="{{ $field['name'] }}" value="{{ $field['value'] }}">
                            @endif
                        </div>
                    @else
                        <div>
                            <label for="field_{{ $field['name'] }}">{{ $field['label'] }}</label>
                            <input
                                id="field_{{ $field['name'] }}"
                                name="{{ $field['name'] }}"
                                type="{{ ($field['type'] ?? 'text') === 'number' ? 'number' : 'text' }}"
                                value="{{ $field['value'] }}"
                                @if(isset($field['min'])) min="{{ $field['min'] }}" @endif
                                @readonly($field['readonly'])
                            >
                        </div>
                    @endif
                @endforeach
            </div>

            <div class="actions" style="margin-top: 22px;">
                <button class="button" type="submit">提交保存</button>
                <a class="button ghost" href="{{ $back_url }}">取消</a>
            </div>
        </form>
    </div>

    @if($reference_summary)
        <div class="panel">
            <div class="actions" style="justify-content: space-between; margin-bottom: 14px;">
                <div>
                    <strong>当前引用摘要</strong>
                    <div class="hint">保存时若触发禁用，或执行删除，会按下面的真实引用结果硬拦截。</div>
                </div>
            </div>

            <div class="grid" style="margin-bottom: 14px;">
                <div>
                    <label>记录主键</label>
                    <div>{{ $reference_summary['record_key'] }}</div>
                </div>
                <div>
                    <label>记录名称</label>
                    <div>{{ $reference_summary['record_label'] ?: '-' }}</div>
                </div>
                <div>
                    <label>禁止禁用</label>
                    <div>{{ $reference_summary['block_disable'] ? '是' : '否' }}</div>
                </div>
                <div>
                    <label>禁止删除</label>
                    <div>{{ $reference_summary['block_delete'] ? '是' : '否' }}</div>
                </div>
            </div>

            @if($reference_summary['disable_references'] !== [])
                <table>
                    <thead>
                        <tr>
                            <th>禁用拦截项</th>
                            <th>数量</th>
                            <th>示例</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($reference_summary['disable_references'] as $reference)
                            <tr>
                                <td>{{ $reference['label'] }}</td>
                                <td>{{ $reference['count'] }}</td>
                                <td>{{ $reference['examples'] === [] ? '-' : implode('，', $reference['examples']) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            @else
                <div class="hint">当前没有会阻止禁用的引用。</div>
            @endif
        </div>
    @endif

    @if($delete_action)
        <div class="panel">
            <div class="actions" style="justify-content: space-between;">
                <div>
                    <strong>危险操作</strong>
                    <div class="hint">删除前会再次执行真实引用检查；若存在下游依赖，将直接拒绝，不会只提示不拦。</div>
                </div>
                <form class="inline" method="POST" action="{{ $delete_action }}">
                    @csrf
                    @method('DELETE')
                    <button class="button danger" type="submit">删除记录</button>
                </form>
            </div>
        </div>
    @endif
@endsection
