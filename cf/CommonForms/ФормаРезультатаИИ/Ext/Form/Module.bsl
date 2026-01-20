
#Область ОбработчикиСобытийФормы

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)

	Если ЭтотОбъект.Параметры.Свойство("Заголовок") Тогда
		ЭтотОбъект.Заголовок = ЭтотОбъект.Параметры.Заголовок;
	КонецЕсли;

	// Получаем данные документа (заголовок, диагнозы)
	ДанныеДокумента = Неопределено;
	Если ЭтотОбъект.Параметры.Свойство("ДанныеДокумента") Тогда
		ДанныеДокумента = ЭтотОбъект.Параметры.ДанныеДокумента;
	КонецЕсли;

	// Получаем JSON с результатом анализа
	JSONСтрока = "";
	Если ЭтотОбъект.Параметры.Свойство("РезультатJSON") Тогда
		JSONСтрока = ЭтотОбъект.Параметры.РезультатJSON;
	КонецЕсли;

	ЭтотОбъект.РезультатHTML = СформироватьHTML(JSONСтрока, ДанныеДокумента);

КонецПроцедуры

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

&НаСервере
Функция СформироватьHTML(JSONСтрока, ДанныеДокумента)

	// Данные документа для шапки
	ЗаголовокДокумента = "";
	Пациент = "";
	ДатаДокумента = "";
	СтрокиДиагнозов = "";

	Если ДанныеДокумента <> Неопределено Тогда
		Если ДанныеДокумента.Свойство("ЗаголовокДокумента") Тогда
			ЗаголовокДокумента = ДанныеДокумента.ЗаголовокДокумента;
		КонецЕсли;
		Если ДанныеДокумента.Свойство("Пациент") Тогда
			Пациент = ДанныеДокумента.Пациент;
		КонецЕсли;
		Если ДанныеДокумента.Свойство("ДатаДокумента") Тогда
			ДатаДокумента = ДанныеДокумента.ДатаДокумента;
		КонецЕсли;
		Если ДанныеДокумента.Свойство("Диагнозы") И ТипЗнч(ДанныеДокумента.Диагнозы) = Тип("Массив") Тогда
			Для Каждого Диагноз Из ДанныеДокумента.Диагнозы Цикл
				ТипДиагноза = "";
				КодДиагноза = "";
				НаименованиеДиагноза = "";
				Если Диагноз.Свойство("Тип") Тогда
					ТипДиагноза = Диагноз.Тип;
				КонецЕсли;
				Если Диагноз.Свойство("Код") Тогда
					КодДиагноза = Диагноз.Код;
				КонецЕсли;
				Если Диагноз.Свойство("Наименование") Тогда
					НаименованиеДиагноза = Диагноз.Наименование;
				КонецЕсли;
				СтрокиДиагнозов = СтрокиДиагнозов + "<div class=""diagnosis-item""><span class=""diagnosis-type"">" + ТипДиагноза + ":</span> <span class=""diagnosis-code"">" + КодДиагноза + "</span> " + НаименованиеДиагноза + "</div>";
			КонецЦикла;
		КонецЕсли;
	КонецЕсли;

	// Пытаемся распарсить JSON
	Данные = Неопределено;
	Попытка
		ЧтениеJSON = Новый ЧтениеJSON;
		ЧтениеJSON.УстановитьСтроку(JSONСтрока);
		Данные = ПрочитатьJSON(ЧтениеJSON);
	Исключение
		// Если не JSON — выводим как текст
		Возврат ПолучитьШаблонОшибки(JSONСтрока);
	КонецПопытки;

	// Формируем строки таблицы услуг
	СтрокиТаблицы = "";
	Если Данные <> Неопределено И Данные.Свойство("items") И ТипЗнч(Данные.items) = Тип("Массив") Тогда
		Для Каждого Элемент Из Данные.items Цикл
			Иконка = "";
			КлассСтроки = "";

			Если Элемент.Свойство("status") Тогда
				Если Элемент.status = "ok" Тогда
					Иконка = "✓";
					КлассСтроки = "status-ok";
				ИначеЕсли Элемент.status = "warning" Тогда
					Иконка = "⚠";
					КлассСтроки = "status-warning";
				ИначеЕсли Элемент.status = "error" Тогда
					Иконка = "✗";
					КлассСтроки = "status-error";
				Иначе
					Иконка = "•";
				КонецЕсли;
			КонецЕсли;

			НазваниеУслуги = "";
			Если Элемент.Свойство("service") Тогда
				НазваниеУслуги = Элемент.service;
			КонецЕсли;

			Комментарий = "";
			Если Элемент.Свойство("comment") Тогда
				Комментарий = Элемент.comment;
			КонецЕсли;

			СтрокиТаблицы = СтрокиТаблицы + "<tr class=""" + КлассСтроки + """><td class=""icon"">" + Иконка + "</td><td class=""service"">" + НазваниеУслуги + "</td><td class=""comment"">" + Комментарий + "</td></tr>";
		КонецЦикла;
	КонецЕсли;

	// Резюме
	Резюме = "";
	Если Данные <> Неопределено И Данные.Свойство("summary") Тогда
		Резюме = Данные.summary;
	КонецЕсли;

	// Рекомендации
	СписокРекомендаций = "";
	Если Данные <> Неопределено И Данные.Свойство("recommendations") И ТипЗнч(Данные.recommendations) = Тип("Массив") Тогда
		Для Каждого Рекомендация Из Данные.recommendations Цикл
			СписокРекомендаций = СписокРекомендаций + "<li>" + Рекомендация + "</li>";
		КонецЦикла;
	КонецЕсли;

	// Подставляем в шаблон
	HTML = ПолучитьШаблонHTML();
	HTML = СтрЗаменить(HTML, "{{DOC_TITLE}}", ЗаголовокДокумента);
	HTML = СтрЗаменить(HTML, "{{PATIENT}}", Пациент);
	HTML = СтрЗаменить(HTML, "{{DOC_DATE}}", ДатаДокумента);
	HTML = СтрЗаменить(HTML, "{{DIAGNOSES}}", СтрокиДиагнозов);
	HTML = СтрЗаменить(HTML, "{{SUMMARY}}", Резюме);
	HTML = СтрЗаменить(HTML, "{{TABLE_ROWS}}", СтрокиТаблицы);
	HTML = СтрЗаменить(HTML, "{{RECOMMENDATIONS}}", СписокРекомендаций);

	Возврат HTML;

КонецФункции

&НаСервере
Функция ПолучитьШаблонHTML()

	Возврат "<!DOCTYPE html>
	|<html>
	|<head>
	|<meta charset=""utf-8"">
	|<style>
	|* { margin: 0; padding: 0; box-sizing: border-box; }
	|body { font-family: 'Segoe UI', Arial, sans-serif; padding: 16px; background: #f8f9fa; color: #333; font-size: 13px; }
	|.header { background: linear-gradient(135deg, #2c5282, #3182ce); color: #fff; padding: 16px; border-radius: 8px; margin-bottom: 16px; }
	|.header-title { font-size: 16px; font-weight: 600; margin-bottom: 8px; }
	|.header-info { font-size: 12px; opacity: 0.9; }
	|.header-info span { margin-right: 16px; }
	|.diagnoses { background: #fff; padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; border-left: 4px solid #e53e3e; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
	|.diagnoses-title { font-size: 12px; color: #666; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px; }
	|.diagnosis-item { margin-bottom: 4px; }
	|.diagnosis-type { color: #718096; }
	|.diagnosis-code { font-weight: 600; color: #e53e3e; }
	|.summary { background: #fff; padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; border-left: 4px solid #38a169; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
	|.summary-title { font-size: 12px; color: #666; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
	|.summary-text { line-height: 1.5; }
	|table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 16px; }
	|th { background: #2c5282; color: #fff; padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 500; }
	|td { padding: 10px 12px; border-bottom: 1px solid #e9ecef; vertical-align: top; }
	|tr:last-child td { border-bottom: none; }
	|tr:hover { background: #f8f9fa; }
	|.icon { width: 30px; text-align: center; font-size: 16px; }
	|.service { width: 40%; font-weight: 500; }
	|.comment { color: #555; }
	|.status-ok .icon { color: #38a169; }
	|.status-warning .icon { color: #d69e2e; }
	|.status-error .icon { color: #e53e3e; }
	|.status-ok { background: #f0fff4; }
	|.status-warning { background: #fffff0; }
	|.status-error { background: #fff5f5; }
	|.recommendations { background: #fff; padding: 12px 16px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
	|.recommendations-title { font-size: 12px; color: #666; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px; }
	|.recommendations ul { margin-left: 20px; }
	|.recommendations li { line-height: 1.6; color: #2c5282; margin-bottom: 4px; }
	|</style>
	|</head>
	|<body>
	|<div class=""header"">
	|<div class=""header-title"">{{DOC_TITLE}}</div>
	|<div class=""header-info""><span>Пациент: {{PATIENT}}</span><span>Дата: {{DOC_DATE}}</span></div>
	|</div>
	|<div class=""diagnoses"">
	|<div class=""diagnoses-title"">Диагнозы</div>
	|{{DIAGNOSES}}
	|</div>
	|<div class=""summary"">
	|<div class=""summary-title"">Заключение ИИ</div>
	|<div class=""summary-text"">{{SUMMARY}}</div>
	|</div>
	|<table>
	|<tr><th class=""icon""></th><th class=""service"">Услуга</th><th class=""comment"">Комментарий</th></tr>
	|{{TABLE_ROWS}}
	|</table>
	|<div class=""recommendations"">
	|<div class=""recommendations-title"">Рекомендации</div>
	|<ul>{{RECOMMENDATIONS}}</ul>
	|</div>
	|</body>
	|</html>";

КонецФункции

&НаСервере
Функция ПолучитьШаблонОшибки(Текст)

	Возврат "<!DOCTYPE html>
	|<html>
	|<head>
	|<meta charset=""utf-8"">
	|<style>
	|body { font-family: 'Segoe UI', Arial, sans-serif; padding: 16px; }
	|pre { white-space: pre-wrap; word-wrap: break-word; background: #f5f5f5; padding: 12px; border-radius: 4px; font-size: 13px; }
	|</style>
	|</head>
	|<body>
	|<p><strong>Не удалось распарсить ответ как JSON:</strong></p>
	|<pre>" + Текст + "</pre>
	|</body>
	|</html>";

КонецФункции

#КонецОбласти
