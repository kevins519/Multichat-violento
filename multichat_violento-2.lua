require "import"

-- EQUIPOS DE NAVEGACIÓN (IMPORTS BLINDADOS)
import "android.widget.*"
import "android.widget.ArrayAdapter"
import "android.net.Uri"
import "android.content.Context"
import "android.widget.Button"
import "android.widget.Spinner"
import "com.androlua.LuaDialog"
import "android.widget.TextView"
import "android.view.Gravity"
import "android.widget.EditText"
import "android.widget.ScrollView"
import "android.widget.LinearLayout"
import "android.view.*"
import "android.content.*"
import "android.os.*"
import "android.graphics.Color"
import "java.io.File"
import "java.util.ArrayList"
import "java.lang.System"
import "com.androlua.Http"
local json = require "cjson"

local context = activity or service

-- 
-- NÚCLEO DE PREFERENCIAS
-- 
local sharedPrefs = context.getSharedPreferences("MultichatViolento_v37", Context.MODE_PRIVATE)

local URL_GROQ = "https://api.groq.com/openai/v1/chat/completions"
local URL_CEREBRAS = "https://api.cerebras.ai/v1/chat/completions"
local URL_MISTRAL = "https://api.mistral.ai/v1/chat/completions"
local URL_SAMBANOVA = "https://api.sambanova.ai/v1/chat/completions"

-- Carpeta donde se guardan las conversaciones
local RUTA_CONVERSACIONES = "/storage/emulated/0/accesorios/Multichat violento"

-- Marcadores del archivo txt (permiten reconstruir la conversación al cargarla)
local MARCA_USUARIO = "=== Tú ==="
local MARCA_IA = "=== IA ==="

-- Memoria de Conversación
local chatHistory = json.decode(sharedPrefs.getString("memoria_violenta", "[]"))

function obtenerApi() return tostring(sharedPrefs.getString("api_sel", "Groq")) end
function obtenerKey(api) return tostring(sharedPrefs.getString(api:lower().."_key", "")) end
function obtenerModel(api) return tostring(sharedPrefs.getString(api:lower().."_model", "default")) end

-- 
-- SINCRONIZACIÓN DE MODELOS
-- 
function syncModels(api, key, spinner, btn)
    local cleanKey = tostring(key):gsub("%s+", "")
    local url_sync = ""
    local headers = {}

    if api == "Gemini" then 
        url_sync = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. cleanKey
    elseif api == "Groq" then 
        url_sync = "https://api.groq.com/openai/v1/models"
        headers["Authorization"] = "Bearer " .. cleanKey
    elseif api == "Cerebras" then 
        url_sync = "https://api.cerebras.ai/v1/models"
        headers["Authorization"] = "Bearer " .. cleanKey
    elseif api == "Mistral" then 
        url_sync = "https://api.mistral.ai/v1/models"
        headers["Authorization"] = "Bearer " .. cleanKey
    elseif api == "SambaNova" then 
        url_sync = "https://api.sambanova.ai/v1/models"
        headers["Authorization"] = "Bearer " .. cleanKey
    end

    btn.setEnabled(false)
    btn.setText("Sincronizando...")
    
    if api == "Gemini" then
        Http.get(url_sync, function(code, content)
            btn.setEnabled(true)
            btn.setText("Sincronizar Modelos")
            if code == 200 then
                local success, res = pcall(json.decode, content)
                if success and res and res.models then
                    local list = {}
                    for _, m in ipairs(res.models) do
                        local name = m.name:gsub("models/", "")
                        list[#list + 1] = name
                    end
                    table.sort(list)
                    spinner.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_dropdown_item, ArrayList(list)))
                    service.speak("Gemini sincronizado.")
                end
            else service.speak("Falla " .. tostring(code) .. " en Gemini") end
        end)
    else
        Http.get(url_sync, headers, function(code, content)
            btn.setEnabled(true)
            btn.setText("Sincronizar Modelos")
            if code == 200 then
                local success, res = pcall(json.decode, content)
                if success and res and res.data then
                    local list = {}
                    for _, m in ipairs(res.data) do
                        table.insert(list, m.id)
                    end
                    table.sort(list)
                    spinner.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_dropdown_item, ArrayList(list)))
                    service.speak(api .. " sincronizado.")
                end
            else service.speak("Falla " .. tostring(code) .. " en " .. api) end
        end)
    end
end

function abrirEnlaceApiActual()
    local api = obtenerApi()
    local url = "https://console.groq.com/keys" -- Valor por defecto
    
    if api == "Gemini" then
        url = "https://makersuite.google.com/app/apikey"
    elseif api == "Groq" then
        url = "https://console.groq.com/keys"
    elseif api == "Cerebras" then
        url = "https://cloud.cerebras.ai/"
     elseif api == "SambaNova" then
        url = "https://cloud.sambanova.ai/"
    elseif api == "Mistral" then
        url = "https://console.mistral.ai/api-keys/"
    end

    local intent = Intent(Intent.ACTION_VIEW)
    intent.setData(Uri.parse(url))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
    
    if service.asyncSpeak then
        service.asyncSpeak("Abriendo enlace para crear clave de " .. api)
    end
dlg.dismiss()
service.click({"%Atrás"})

if dlg then
dlg.dismiss()
end
if activity then
activity.finish()
end
if service then
service.stopSelf()
end
return true
end
function agregarBloqueCrearClave(layout)
    local txtNoKey = TextView(context)
    txtNoKey.setText("¿No tienes una clave Api?")
    txtNoKey.setTextSize(14)
    txtNoKey.setPadding(0, 10, 0, 5)
    layout.addView(txtNoKey)

    local btnCrearKey = Button(context)
    btnCrearKey.setText("Crear clave Api (" .. obtenerApi() .. ")")
    btnCrearKey.setOnClickListener(function()
        abrirEnlaceApiActual()
    end)
    layout.addView(btnCrearKey)
end

--CONFIGURACIÓN
function mostrarConfiguracion()
    local api = obtenerApi()
    dlg = LuaDialog(context)
    dlg.setTitle("Configuración Violenta")
    
    local layout = LinearLayout(context)
    layout.setOrientation(1)
    layout.setPadding(30, 30, 30, 30)

    local btnSwap = Button(context)
    btnSwap.setText(tostring("Cambiar API (Actual: "..api..")"))
    btnSwap.setOnClickListener(function()
        local apis = {"Groq", "Gemini", "Cerebras", "Mistral", "SambaNova"}
        local cur = obtenerApi()
        local nxt = "Groq"
        for i, v in ipairs(apis) do if v == cur then nxt = apis[i+1] or apis[1] break end end
        sharedPrefs.edit().putString("api_sel", nxt).commit()
        dlg.dismiss()
        mostrarConfiguracion()
    end)
    layout.addView(btnSwap)

    local inputKey = EditText(context)
    inputKey.setHint(tostring("Pega tu API Key de "..api))
    inputKey.setText(obtenerKey(api))
    layout.addView(inputKey)
agregarBloqueCrearClave(layout)

    local spinner = Spinner(context)
    spinner.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_dropdown_item, ArrayList({obtenerModel(api)})))
    layout.addView(spinner)

    local btnSyn = Button(context)
    btnSyn.setText("Sincronizar Modelos")
    btnSyn.setOnClickListener(function() syncModels(api, tostring(inputKey.getText()), spinner, btnSyn) end)
    layout.addView(btnSyn)

    local btnSave = Button(context)
    btnSave.setText("Guardar")
    btnSave.setOnClickListener(function()
        local ed = sharedPrefs.edit()
        ed.putString(api:lower().."_key", tostring(inputKey.getText()))
        if spinner.getSelectedItem() then ed.putString(api:lower().."_model", tostring(spinner.getSelectedItem())) end
        ed.commit()
        service.speak("Configuración de "..api.." guardada.")
        dlg.dismiss()
    end)
    layout.addView(btnSave)

    local btnExit = Button(context)
    btnExit.setText("Salir")
    btnExit.setOnClickListener(function() dlg.dismiss() end)
    layout.addView(btnExit)

    dlg.setView(layout)
    dlg.show()
end

-- 
-- CONTROLADOR DE MENSAJES (ESTADOS Y GESTOS)
-- 
function updateMessageView(view, title, text, status)
    if not view then return end
    
    local currentStatus = view.getTag()
    
    -- Si la vista cayó en error, bloqueamos cualquier intento tardío del callback de cambiar a "sent"
    if currentStatus == "error" and status == "sent" then
        return
    end

    local finalStatus = (status == "retrying") and "waiting" or status
    view.setTag(finalStatus)

    local statusText = ""
    if finalStatus == "waiting" then
        statusText = " [⏳ Esperando... Tocas para reintentar]"
    elseif finalStatus == "error" then
        statusText = " [❌ Falló el envío. Tocas para reintentar]"
    elseif finalStatus == "sent" then
        statusText = " [✓ Enviado]"
    end
    
    view.setText(title .. statusText .. "\n" .. text)
end

function addMessage(container, title, msg, colorInt, status, isUser, retryCallback)
    local txt = TextView(context)
    txt.setTextColor(colorInt)
    txt.setTextIsSelectable(true)
    txt.setPadding(12, 12, 12, 12)
    
    updateMessageView(txt, title, msg, status)
    container.addView(txt)

    if isUser then
        local lastClickTime = 0
        txt.setOnClickListener(function()
            local currentTime = System.currentTimeMillis()
            local currentStatus = txt.getTag()
            
            -- 1. Doble clic (< 300ms): Reenvía el mensaje como nueva consulta siempre
            if currentTime - lastClickTime < 300 then
                if retryCallback then
                    service.speak("Reenviando mensaje...")
                    updateMessageView(txt, "Tú:", msg, "retrying")
                    retryCallback(msg, true)
                end
            else
                -- 2. Clic simple: Ignorado si ya está enviado para evitar error 400
                if currentStatus == "sent" then
                    return
                elseif currentStatus == "error" or currentStatus == "waiting" then
                    if retryCallback then
                        service.speak("Reintentando envío...")
                        updateMessageView(txt, "Tú:", msg, "retrying")
                        retryCallback(msg, false)
                    end
                end
            end
            lastClickTime = currentTime
        end)
    end

    return txt
end

-- 
-- ENVÍO DE DATOS
-- 
function processApiRequest(text, container, userMsgView, isRequote)
    local api = obtenerApi()
    local key = obtenerKey(api)
    local mod = obtenerModel(api)
    
    if key == "" then 
        service.speak("Falta clave API de "..api) 
        if userMsgView then updateMessageView(userMsgView, "Tú:", text, "error") end
        return 
    end

    -- CORTE INMEDIATO SI NO HAY INTERNET
    local cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
    local netInfo = cm and cm.getActiveNetworkInfo()
    local isConnected = netInfo and netInfo.isConnected()

    if not isConnected then
        if userMsgView then 
            updateMessageView(userMsgView, "Tú:", text, "error") 
            
            -- Guardamos en memoria con estado 'error' para que no desaparezca al salir del plugin
            local found = false
            for i = #chatHistory, 1, -1 do
                if chatHistory[i].role == "user" and chatHistory[i].content == text then
                    chatHistory[i].status = "error"
                    found = true
                    break
                end
            end
            if not found then
                table.insert(chatHistory, {role = "user", content = text, status = "error"})
            end
            sharedPrefs.edit().putString("memoria_violenta", json.encode(chatHistory)).commit()
        end
        service.speak("Sin conexión a internet")
        return
    end

    if userMsgView then
        updateMessageView(userMsgView, "Tú:", text, "waiting")
    end

    local url_post = ""
    local payload = {}

    service.speak("Enviando consulta a "..api.."...")

    if api == "Gemini" then
        local url_g = "https://generativelanguage.googleapis.com/v1beta/models/"..tostring(mod):gsub("%s+", "")..":generateContent?key="..tostring(key):gsub("%s+", "")
        local contents = {}
        for _, m in ipairs(chatHistory) do 
            table.insert(contents, {role = (m.role == "user" and "user" or "model"), parts = {{text = m.content}}}) 
        end
        table.insert(contents, {role = "user", parts = {{text = text}}})

        local requestId = System.currentTimeMillis()
        if userMsgView then userMsgView.setTag(requestId) end

        Http.post(url_g, json.encode({contents = contents}), {["Content-Type"]="application/json"}, function(code, content)
            if userMsgView and userMsgView.getTag() == "error" then return end

            if code == 200 then
                local success, res = pcall(json.decode, content)
                if success and res and res.candidates and res.candidates[1] and res.candidates[1].content and res.candidates[1].content.parts and res.candidates[1].content.parts[1] then
    local ans = res.candidates[1].content.parts[1].text
                    
                    local found = false
                    for i = #chatHistory, 1, -1 do
                        if chatHistory[i].role == "user" and chatHistory[i].content == text then
                            chatHistory[i].status = "sent"
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(chatHistory, {role = "user", content = text, status = "sent"})
                    end
                    
                    table.insert(chatHistory, {role = "assistant", content = ans})
                    sharedPrefs.edit().putString("memoria_violenta", json.encode(chatHistory)).commit()
                    
                    if userMsgView then updateMessageView(userMsgView, "Tú:", text, "sent") end
                    addMessage(container, "Gemini:", ans, 0xFFFFFFFF, nil, false, nil)
                    service.speak(ans)
                else
                    if userMsgView then updateMessageView(userMsgView, "Tú:", text, "error") end
                end
            else
                if userMsgView then updateMessageView(userMsgView, "Tú:", text, "error") end
                service.speak("Error de conexión en Gemini")
            end
        end)
    else
        if api == "Groq" then url_post = URL_GROQ
        elseif api == "Cerebras" then url_post = URL_CEREBRAS
        elseif api == "Mistral" then url_post = URL_MISTRAL
        elseif api == "SambaNova" then url_post = URL_SAMBANOVA end
        
        local tempHistory = {}
        for _, m in ipairs(chatHistory) do table.insert(tempHistory, m) end
        table.insert(tempHistory, {role = "user", content = text})

        payload = { model = mod, messages = tempHistory, temperature = 0.7 }

        local requestId = System.currentTimeMillis()
        if userMsgView then userMsgView.setTag(requestId) end

        Http.post(url_post, json.encode(payload), {["Authorization"]="Bearer "..key, ["Content-Type"]="application/json"}, function(code, content)
            if userMsgView and userMsgView.getTag() == "error" then return end

            if code == 200 then
                local success, res = pcall(json.decode, content)
                if success and res and res.choices then
                    local ans = res.choices[1].message.content
                    
                    local found = false
                    for i = #chatHistory, 1, -1 do
                        if chatHistory[i].role == "user" and chatHistory[i].content == text then
                            chatHistory[i].status = "sent"
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(chatHistory, {role = "user", content = text, status = "sent"})
                    end
                    
                    table.insert(chatHistory, {role = "assistant", content = ans})
                    sharedPrefs.edit().putString("memoria_violenta", json.encode(chatHistory)).commit()
                    
                    if userMsgView then updateMessageView(userMsgView, "Tú:", text, "sent") end
                    addMessage(container, api..":", ans, 0xFFFFFFFF, nil, false, nil)
                    service.speak(ans)
                else
                    if userMsgView then updateMessageView(userMsgView, "Tú:", text, "error") end
                end
            else
                if userMsgView then updateMessageView(userMsgView, "Tú:", text, "error") end
                service.speak("Error de conexión en " .. api)
            end
        end)
    end
end

function sendCommand(text, container)
    local userMsgView
    local function executeRequest(msgText, isNew)
        if isNew then
            sendCommand(msgText, container)
        else
            processApiRequest(msgText, container, userMsgView, false)
        end
    end

    userMsgView = addMessage(container, "Tú:", text, 0xFF00FF00, "waiting", true, executeRequest)
    processApiRequest(text, container, userMsgView, true)
end

-- 
-- RENDERIZADO DEL HISTORIAL EN PANTALLA
-- 
function renderHistory(container)
    container.removeAllViews()
    for _, m in ipairs(chatHistory) do
        if m.role == "user" then
            addMessage(container, "Tú:", m.content, 0xFF00FF00, m.status or "sent", true, function(msgText, isNew)
                sendCommand(msgText, container)
            end)
        else
            addMessage(container, "IA:", m.content, 0xFFFFFFFF, nil, false, nil)
        end
    end
end

-- 
-- GUARDAR / CARGAR / ELIMINAR CONVERSACIONES
-- 
function limpiarNombreArchivo(nombre)
    local n = tostring(nombre)
    n = n:gsub('[\\/:*?"<>|]', "_")
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

function rutaDisponible(base)
    local ruta = RUTA_CONVERSACIONES .. "/" .. base .. ".txt"
    local n = 1
    while File(ruta).exists() do
        ruta = RUTA_CONVERSACIONES .. "/" .. base .. " (" .. n .. ").txt"
        n = n + 1
    end
    return ruta
end

function guardarConversacionEnArchivo(nombreUsuario)
    local nombre = limpiarNombreArchivo(nombreUsuario or "")
    if nombre == "" then
        nombre = "Chat violento " .. os.date("%Y-%m-%d_%H-%M-%S")
    end
    nombre = nombre:gsub("%.txt$", "")

    local carpeta = File(RUTA_CONVERSACIONES)
    if not carpeta.exists() then carpeta.mkdirs() end

    local ruta = rutaDisponible(nombre)

    local partes = {}
    for _, m in ipairs(chatHistory) do
        local marca = (m.role == "user") and MARCA_USUARIO or MARCA_IA
        table.insert(partes, marca .. "\n" .. tostring(m.content) .. "\n")
    end

    local f = io.open(ruta, "w")
    if not f then
        return false, "No se pudo crear el archivo. Revisa los permisos de almacenamiento."
    end
    f:write(table.concat(partes, "\n"))
    f:close()
    return true, tostring(File(ruta).getName())
end

function leerConversacionDeArchivo(ruta)
    local f = io.open(ruta, "r")
    if not f then return nil end
    local contenido = f:read("*a")
    f:close()

    local historial = {}
    local rolActual = nil
    local buffer = {}

    local function cerrarMensaje()
        if rolActual then
            local texto = table.concat(buffer, "\n"):gsub("%s+$", "")
            if texto ~= "" then
                if rolActual == "user" then
                    table.insert(historial, {role = "user", content = texto, status = "sent"})
                else
                    table.insert(historial, {role = "assistant", content = texto})
                end
            end
        end
        buffer = {}
    end

    for linea in (contenido .. "\n"):gmatch("(.-)\n") do
        linea = linea:gsub("\r$", "")
        if linea == MARCA_USUARIO then
            cerrarMensaje()
            rolActual = "user"
        elseif linea == MARCA_IA then
            cerrarMensaje()
            rolActual = "assistant"
        else
            table.insert(buffer, linea)
        end
    end
    cerrarMensaje()

    return historial
end

function dialogoConfirmar(titulo, mensaje, alAceptar)
    local d = LuaDialog(context)
    d.setTitle(titulo)

    local lay = LinearLayout(context)
    lay.setOrientation(1)
    lay.setPadding(30, 30, 30, 30)

    local tv = TextView(context)
    tv.setText(mensaje)
    tv.setTextSize(16)
    lay.addView(tv)

    local btnOk = Button(context)
    btnOk.setText("Aceptar")
    btnOk.setOnClickListener(function()
        d.dismiss()
        alAceptar()
    end)
    lay.addView(btnOk)

    local btnCancel = Button(context)
    btnCancel.setText("Cancelar")
    btnCancel.setOnClickListener(function() d.dismiss() end)
    lay.addView(btnCancel)

    d.setView(lay)
    d.show()
end

function mostrarDialogoGuardar(container)
    if #chatHistory == 0 then
        service.speak("No hay mensajes para guardar.")
        return
    end

    local d = LuaDialog(context)
    d.setTitle("Guardar conversación")

    local lay = LinearLayout(context)
    lay.setOrientation(1)
    lay.setPadding(30, 30, 30, 30)

    local input = EditText(context)
    input.setHint("Nombre del archivo (opcional)")
    lay.addView(input)

    local btnOk = Button(context)
    btnOk.setText("Aceptar")
    btnOk.setOnClickListener(function()
        local ok, res = guardarConversacionEnArchivo(tostring(input.getText()))
        if ok then
            -- Al guardar: la memoria se limpia y el chat queda en blanco
            chatHistory = {}
            sharedPrefs.edit().remove("memoria_violenta").commit()
            container.removeAllViews()
            d.dismiss()
            service.speak("Conversación guardada como " .. res)
        else
            service.speak(res)
        end
    end)
    lay.addView(btnOk)

    local btnCancel = Button(context)
    btnCancel.setText("Cancelar")
    btnCancel.setOnClickListener(function() d.dismiss() end)
    lay.addView(btnCancel)

    d.setView(lay)
    d.show()
end

function mostrarConversaciones(container)
    local d = LuaDialog(context)
    d.setTitle("Conversaciones")

    local root = LinearLayout(context)
    root.setOrientation(1)
    root.setPadding(30, 30, 30, 30)

    local scroll = ScrollView(context)
    scroll.setLayoutParams(LinearLayout.LayoutParams(-1, 0, 1))
    local lista = LinearLayout(context)
    lista.setOrientation(1)
    scroll.addView(lista)
    root.addView(scroll)

    -- Leer archivos guardados
    local items = {}
    local archivos = File(RUTA_CONVERSACIONES).listFiles()
    if archivos then
        local listaArchivos = luajava.astable(archivos)
        for _, f in ipairs(listaArchivos) do
            local nombre = tostring(f.getName())
            if f.isFile() and nombre:lower():match("%.txt$") then
                table.insert(items, {nombre = nombre, ruta = tostring(f.getAbsolutePath()), tiempo = f.lastModified()})
            end
        end
    end
    table.sort(items, function(a, b) return a.tiempo > b.tiempo end)

    if #items == 0 then
        local vacio = TextView(context)
        vacio.setText("No hay conversaciones guardadas.")
        vacio.setTextSize(16)
        vacio.setPadding(0, 10, 0, 10)
        lista.addView(vacio)
    end

    for _, it in ipairs(items) do
        local btn = Button(context)
        btn.setText((it.nombre:gsub("%.[Tt][Xx][Tt]$", "")))

        -- Clic: arma la conversación en memoria para continuar
        btn.setOnClickListener(function()
            local historial = leerConversacionDeArchivo(it.ruta)
            if not historial or #historial == 0 then
                service.speak("No se pudo leer la conversación.")
                return
            end
            chatHistory = historial
            sharedPrefs.edit().putString("memoria_violenta", json.encode(chatHistory)).commit()
            renderHistory(container)
            d.dismiss()
            service.speak("Conversación cargada.")
        end)

        -- Pulsación larga: diálogo para eliminar
        btn.setOnLongClickListener(function()
            dialogoConfirmar("Eliminar conversación", "¿Eliminar \"" .. it.nombre .. "\"?", function()
                if File(it.ruta).delete() then
                    service.speak("Conversación eliminada.")
                else
                    service.speak("No se pudo eliminar la conversación.")
                end
                d.dismiss()
                mostrarConversaciones(container)
            end)
            return true
        end)

        lista.addView(btn)
    end

    local btnSalir = Button(context)
    btnSalir.setText("Salir")
    btnSalir.setOnClickListener(function() d.dismiss() end)
    root.addView(btnSalir)

    d.setView(root)
    d.show()
end

-- 
-- INTERFAZ PRINCIPAL
-- 
function mainUI()
    local mainDlg = LuaDialog(context)
    mainDlg.setTitle("Multichat Violento")
    
    local root = LinearLayout(context)
    root.setOrientation(1)
    root.setBackgroundColor(0xFF000000)

    local scroll = ScrollView(context)
    local scrollParams = LinearLayout.LayoutParams(-1, 0, 1)
    scroll.setLayoutParams(scrollParams)
    
    local msgContainer = LinearLayout(context)
    msgContainer.setOrientation(1)
    scroll.addView(msgContainer)

    -- Cargar historial previo conservando los estados guardados
    renderHistory(msgContainer)
    root.addView(scroll)

    local btnFinal = Button(context)
    btnFinal.setText("Ir al final")
    btnFinal.setOnClickListener(function()
        scroll.fullScroll(View.FOCUS_DOWN)
    end)
    root.addView(btnFinal)

    local input = EditText(context)
    input.setMaxHeight(600)
    input.setHint("Escribe tu consulta...")
    input.setHintTextColor(0xFF888888)
    input.setTextColor(0xFFFFFFFF)
    input.setGravity(Gravity.TOP)
    input.setMinLines(5)
    root.addView(input)

    local btnBar = LinearLayout(context)
    btnBar.setOrientation(0)
    btnBar.setGravity(Gravity.CENTER)
    local lp = LinearLayout.LayoutParams(0, -2, 1)
    
    -- 1. Enviar
    local btnSend = Button(context)
    btnSend.setText("Enviar")
    btnSend.setOnClickListener(function()
        local t = tostring(input.getText())
        if t ~= "" then 
            sendCommand(t, msgContainer) 
            input.setText("") 
        end
    end)
    btnSend.setLayoutParams(lp)
    btnBar.addView(btnSend)

    -- 2. Limpiar
    local btnClear = Button(context)
    btnClear.setText("Limpiar")
    btnClear.setOnClickListener(function() 
        msgContainer.removeAllViews() 
        local editor = sharedPrefs.edit()
        editor.remove("memoria_violenta")
        editor.commit()
        chatHistory = {} 
        service.speak("Memoria limpia.")
    end)
    btnClear.setLayoutParams(lp)
    btnBar.addView(btnClear)

    -- 3. Conversaciones
    local btnConv = Button(context)
    btnConv.setText("Conversaciones")
    btnConv.setOnClickListener(function() mostrarConversaciones(msgContainer) end)
    btnConv.setLayoutParams(lp)
    btnBar.addView(btnConv)

    -- 4. Guardar
    local btnGuardar = Button(context)
    btnGuardar.setText("Guardar")
    btnGuardar.setOnClickListener(function() mostrarDialogoGuardar(msgContainer) end)
    btnGuardar.setLayoutParams(lp)
    btnBar.addView(btnGuardar)

    -- 5. Configuración
    local btnConfig = Button(context)
    btnConfig.setText("⚙️ Configuración")
    btnConfig.setOnClickListener(function() mostrarConfiguracion() end)
    btnConfig.setLayoutParams(lp)
    btnBar.addView(btnConfig)

    -- 6. Salir
    local btnClose = Button(context)
    btnClose.setText("Salir")
    btnClose.setOnClickListener(function() mainDlg.dismiss() end)
    btnClose.setLayoutParams(lp)
    btnBar.addView(btnClose)

    root.addView(btnBar)
    mainDlg.setView(root)
    mainDlg.show()
end

-- ENCENDIDO DEL SISTEMA
mainUI()
