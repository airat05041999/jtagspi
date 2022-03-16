// tcp_client.cpp : Этот файл содержит функцию "main". Здесь начинается и заканчивается выполнение программы.
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
    char server_message[100] , client_message[181] = "123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789123456789";


    // Очистить буфер:
    //memset(server_message, '\0', sizeof(server_message));
    //memset(client_message, '\0', sizeof(client_message));

    // Создаем сокет:
    socket_desc = socket(AF_INET, SOCK_STREAM, 0);

    if (socket_desc < 0) {
        printf("Unable to create socket\n");
        return -1;
    }

    printf("Socket created successfully\n");

    // порт и IP:
    server_addr.sin_port = htons(5000);
    server_addr.sin_family = AF_INET;
    inet_pton(AF_INET, "192.168.1.2", &server_addr.sin_addr);


    // Отправляем запрос на подключение к серверу:
    if (connect(socket_desc, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        printf("Unable to connect\n");
        return -1;
    }
    printf("Connected with server successfully\n");

    //printf("Enter message: ");
    //gets_s(client_message);


    // Отправляем сообщение на сервер:
    if (send(socket_desc, client_message, strlen(client_message), 0) < 0) {
        printf("Unable to send message\n");
        return -1;
    }

    printf("Enter message: ");
    gets_s(client_message);


    // Receive the server's response:
    if (recv(socket_desc, server_message, sizeof(server_message), 0) < 0) {
        printf("Error while receiving server's msg\n");
        return -1;
    }

    printf("Server's response: %s\n", server_message);

    // Close the socket:
    closesocket(socket_desc);

    return 0;

}

