# jtagspi
 реконфигурация ПЛИС с помощью W5500
26.01.2022
Была проведена отладка, уменьшена частота, исправлены логические ошибки и видоизменнена работа SPI модуля (clk передеается только с помощью cs). Устройство все еще не работает как должно.
27.01.2022
Был перестроен проект, отладка не дала положительный результат. Устройство все еще не работает как должно.
02.02.2022
Был переписан код модуля spi, sclk может подаваться с меньшей частой чем clk, добавлены задержки перед и после траназакции.
03.02.2022
Проводилось устранение логических ошибок. Все еще не получилось вделать внутренюю синхронизацию, чтобы все работало гладко.
04.02.2022
Была проведена верификация. Чтение из регистра w5500 проходит успешно, при большом количестве попыток.
05.02.2022
Была добавлена запись, она пока работает не корректно, ошибка пока не найдена.
09.02.2022
Были испраавлены ошибки. Запись идет корректно. был сначало считан регистр потом записаны в него данные и потом опять чтение, в результате этого была проверена корректность работы. Идето анализ документации с целью установить TCP соединение.
10.02.2022
Была полностью проанализована спецификацию. Был составлен на бумаге алгоритм начальной инициализации и работы управляющего автомата для TCP обмена.
11.02.2022
Были проинциализованы начальные регистры в плате W5500.
12.02.2022
Идет процесс написания управляющего автомата
17.02.2022
Закончен черновой вариант управляющего автомата
18.02.2022
Началась отладка, с целью достежения состояния сокета listen, чтобы перейти к написанию программы на си.
21.02.2022
программа адаптировна под виндувс, ошибка исправлена до этапа листен сокет доходит
24.02.2022
Удалось создать сокет
25.02.2022
удалось написать базовое клиенское приложение, ведется работа по утановление физического соединения
26.02.2020
Удалось установить соединение
03.03.2022
Удалось отпаравить сообщение и считать его длину.