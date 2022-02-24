﻿// tcp_client.cpp : Этот файл содержит функцию "main". Здесь начинается и заканчивается выполнение программы.
//

#define WIN32_LEAN_AND_MEAN
#include <iostream>
#include <cstdio>
#include <stdio.h>
#include <string.h>
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>
#include <stdio.h>
#pragma comment (lib, "Ws2_32.lib")
#pragma comment (lib, "Mswsock.lib")
#pragma comment (lib, "AdvApi32.lib")
using namespace std;
int i_error = 0;
int main(void)
{
    //0. настройка библиотеки Ws2_32.dll
    WSADATA wsaData;//определяем переменную
    i_error = WSAStartup(MAKEWORD(2, 2), &wsaData);//настраиваем
    if (i_error)
    {
        printf("ERROR!\n");
    }
    else
    {
        printf("Biblioteka uspehno sozdana!\n");
    }
    int socket_desc;
    struct sockaddr_in server_addr {};;
    char client_message[2000];


    // Очистить буферы:
    memset(client_message, '\0', sizeof(client_message));

    // Создаем сокет:
    socket_desc = socket(AF_INET, SOCK_STREAM, 0);

    if (socket_desc < 0) {
        printf("Unable to create socket\n");
        return -1;
    }

    printf("Socket created successfully\n");

    // порт и IP:
    server_addr.sin_port = htons(5000);
    inet_pton(AF_INET, "0.0.0.0", &server_addr.sin_addr.s_addr);


    // Отправляем запрос на подключение к серверу:
    if (connect(socket_desc, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        printf("Unable to connect\n");
        return -1;
    }
    printf("Connected with server successfully\n");

    // Получаем ввод от пользователя:
    printf("Enter message: ");
    gets_s(client_message);

    // Отправляем сообщение на сервер:
    if (send(socket_desc, client_message, strlen(client_message), 0) < 0) {
        printf("Unable to send message\n");
        return -1;
    }


    // Закрыть сокет:
    closesocket(socket_desc);

    return 0;
}


// Запуск программы: CTRL+F5 или меню "Отладка" > "Запуск без отладки"
// Отладка программы: F5 или меню "Отладка" > "Запустить отладку"

// Советы по началу работы 
//   1. В окне обозревателя решений можно добавлять файлы и управлять ими.
//   2. В окне Team Explorer можно подключиться к системе управления версиями.
//   3. В окне "Выходные данные" можно просматривать выходные данные сборки и другие сообщения.
//   4. В окне "Список ошибок" можно просматривать ошибки.
//   5. Последовательно выберите пункты меню "Проект" > "Добавить новый элемент", чтобы создать файлы кода, или "Проект" > "Добавить существующий элемент", чтобы добавить в проект существующие файлы кода.
//   6. Чтобы снова открыть этот проект позже, выберите пункты меню "Файл" > "Открыть" > "Проект" и выберите SLN-файл.
